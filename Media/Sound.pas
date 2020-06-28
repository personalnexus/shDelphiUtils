unit Sound;
    
interface
    
uses
  SysUtils, Classes, ExtCtrls, MMSystem, Windows;

type
  TPercentage = 0..100;

  TVolumeMonitor = class;

  TVolumeMonitorTargetViolationEvent = procedure(Sender: TVolumeMonitor; AVolumePercentage: TPercentage; var SetToTargetVolume: Boolean);

  TVolumeMonitorErrorEvent = procedure(Sender: TVolumeMonitor; const ErrorMessage: string);

  ///<summary>Monitors the current volume against a given target volume and reports and/or adjusts the current volume to match the target</summary>
  TVolumeMonitor = class(TObject)
  private
    FCheckTimer:        TTimer;
    FCheckInterval:     Cardinal;
    FLastCheck:         TDateTime;
    FLastViolation:     TDateTime;
    FOnError:           TVolumeMonitorErrorEvent;
    FOnTargetViolation: TVolumeMonitorTargetViolationEvent;
    FTargetVolume:      TPercentage;
    FAutoAdjustVolume:  Boolean;
    procedure CheckTimed(Sender: TObject);
    procedure SetCheckInterval(AValue: Cardinal);

  public
    constructor Create;
    destructor Destroy; override;

    procedure Check;

    property AutoAdjustVolume: Boolean read FAutoAdjustVolume write FAutoAdjustVolume;
    property CheckInterval: Cardinal read FCheckInterval write SetCheckInterval;
    property LastCheck: TDateTime read FLastCheck;
    property LastViolation: TDateTime read FLastViolation;
    property TargetVolume: TPercentage read FTargetVolume write FTargetVolume;

    property OnTargetViolation: TVolumeMonitorTargetViolationEvent read FOnTargetViolation write FOnTargetViolation;
    property OnError: TVolumeMonitorErrorEvent read FOnError write FOnError;
  end;


function WaveMapperSupports(ACapability: Cardinal): Boolean;
function WaveOutGetVolumePercentage(out AVolumePercentage: TPercentage): Cardinal;
function WaveOutSetVolumePercentage(AVolumePercentage: TPercentage): Cardinal;


implementation


function WaveMapperSupports(ACapability: Cardinal): Boolean;
var
    WaveOutCaps: TWAVEOUTCAPS;
begin
    Result := (WaveOutGetDevCaps(WAVE_MAPPER, @WaveOutCaps, SizeOf(WaveOutCaps)) = MMSYSERR_NOERROR)
              and
              (WaveOutCaps.dwSupport and ACapability = ACapability);
end;

function WaveOutGetVolumePercentage(out AVolumePercentage: TPercentage): Cardinal;
var
  Volume:     Cardinal;
  LeftVolume: Word;
begin
  {$WARN BOUNDS_ERROR OFF}
  Result := WaveOutGetVolume(WAVE_MAPPER, @Volume);
  {$WARN BOUNDS_ERROR ON}
  if (Result = MMSYSERR_NOERROR) then begin
    LeftVolume := Lo(Volume);
    AVolumePercentage := Round(100 * LeftVolume / MAXWORD);
  end;
end;

function WaveOutSetVolumePercentage(AVolumePercentage: TPercentage): Cardinal;
var
  Volume: Word;
begin
  Volume := Round(MAXWORD * AVolumePercentage / 100);
  {$WARN BOUNDS_ERROR OFF}
  Result := WaveOutSetVolume(WAVE_MAPPER, MakeLong(Volume, Volume));
  {$WARN BOUNDS_ERROR ON}
end;

{ TVolumeMonitor - Initialization/finalization }

constructor TVolumeMonitor.Create;
begin
  inherited Create;
  //TODO: is it valid to assume the capabilities do not change until Check() is called?
  if (not WaveMapperSupports(WAVECAPS_VOLUME)) then begin
    raise EInvalidOperation.Create('Cannot monitor volume, because WAVECAPS_VOLUME is not supported.' );
  end;
  FCheckTimer := TTimer.Create(nil);
  FCheckTimer.OnTimer := Check;
  FCheckTimer.Interval := 0;
  FCheckTimer.Enabled := True;

  FAutoAdjustVolume := True;
end;

destructor TVolumeMonitor.Destroy;
begin
  FreeAndNil(FCheckTimer);
  inherited Destroy;
end;

{ TVolumeMonitor - Main functionality }

procedure TVolumeMonitor.CheckTimed(Sender: TObject);
begin
  Check;
end;

procedure TVolumeMonitor.Check;
var
  ReturnCode:    Cardinal;
  CurrentVolume: TPercentage;
  AdjustVolume:  Boolean;
  Timestamp:     TDateTime;
begin
  ReturnCode := WaveOutGetVolumePercentage(CurrentVolume);
  if (ReturnCode <> MMSYSERR_NOERROR) then begin
    if (Assigned(FOnError)) then begin
      FOnError(Self, Format('Failed to get volume. Error: %d', [ReturnCode]));
    end;
  end else begin
    Timestamp := Now;
    if (CurrentVolume <> FTargetVolume) then begin
      AdjustVolume := FAutoAdjustVolume;
      if (Assigned(FOnTargetViolation)) then begin
         // Event handler can decide whether they want to let the violation
         // slide or even set TargetVolume to some new value.
         FOnTargetViolation(Self, CurrentVolume, AdjustVolume);
      end;
      if (AdjustVolume and (CurrentVolume <> FTargetVolume)) then begin
        WaveOutSetVolumePercentage(FTargetVolume);
      end;
      FLastViolation := Timestamp;
    end;
    FLastCheck := Timestamp;
  end;
end;

{ TVolumeMonitor - Getter/setter }

procedure TVolumeMonitor.SetCheckInterval(AValue: Cardinal);
begin
  FCheckTimer.Interval := AValue;
end;
    
end.