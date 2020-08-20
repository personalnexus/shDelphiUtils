unit Sound;
    
interface
    
uses
  SysUtils, Classes, ExtCtrls, MMSystem, Windows;

type
  TPercentage = 0..100;

  TVolumeMonitor = class;

  TVolumeMonitorTargetViolationEvent = procedure(Sender: TVolumeMonitor; AVolumePercentage: TPercentage; var SetToTargetVolume: Boolean) of object;

  TVolumeMonitorErrorEvent = procedure(Sender: TVolumeMonitor; const ErrorMessage: string) of object;

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

    function CallWithErrorHandling(AOperation: string; AReturnCode: Cardinal): Boolean;

  public
    constructor Create;
    constructor CreateStarted(ACheckInterval: Cardinal);
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
function WaveOutGetVolumePercentage(out AVolumePercentage: TPercentage): Cardinal; overload;
function WaveOutGetVolumePercentage(out ALeftVolumePercentage, ARightVolumePercentage: TPercentage): Cardinal; overload;
function WaveOutSetVolumePercentage(AVolumePercentage: TPercentage): Cardinal; overload;
function WaveOutSetVolumePercentage(ALeftVolumePercentage, ARightVolumePercentage: TPercentage): Cardinal; overload;


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
  _: TPercentage;
begin
  Result := WaveOutGetVolumePercentage(AVolumePercentage, _);
end;

function WaveOutGetVolumePercentage(out ALeftVolumePercentage, ARightVolumePercentage: TPercentage): Cardinal;
var
  Volume:      Cardinal;
  LeftVolume:  Word;
  RightVolume: Word;
begin
  {$WARN BOUNDS_ERROR OFF}
  Result := WaveOutGetVolume(WAVE_MAPPER, @Volume);
  {$WARN BOUNDS_ERROR ON}
  if (Result = MMSYSERR_NOERROR) then begin
    LeftVolume := LoWord(Volume);
    ALeftVolumePercentage := Round(100 * LeftVolume / MAXWORD);
    RightVolume := HiWord(Volume);
    ARightVolumePercentage := Round(100 * RightVolume / MAXWORD);
  end;
end;

function WaveOutSetVolumePercentage(AVolumePercentage: TPercentage): Cardinal;
begin
  Result := WaveOutSetVolumePercentage(AVolumePercentage, AVolumePercentage);
end;

function WaveOutSetVolumePercentage(ALeftVolumePercentage, ARightVolumePercentage: TPercentage): Cardinal;
var
  LeftVolume:  Word;
  RightVolume: Word;
begin
  LeftVolume  := Round(MAXWORD * ALeftVolumePercentage / 100);
  RightVolume := Round(MAXWORD * ARightVolumePercentage / 100);
  {$WARN BOUNDS_ERROR OFF}
  Result := WaveOutSetVolume(WAVE_MAPPER, MakeLong(LeftVolume, RightVolume));
  {$WARN BOUNDS_ERROR ON}
end;

{ TVolumeMonitor - Initialization/finalization }

constructor TVolumeMonitor.CreateStarted(ACheckInterval: Cardinal);
begin
  Create;
  CheckInterval := ACheckInterval;
end;

constructor TVolumeMonitor.Create;
begin
  inherited Create;
  //TODO: is it valid to assume the capabilities do not change until Check() is called?
  if (not WaveMapperSupports(WAVECAPS_VOLUME)) then begin
    raise EInvalidOperation.Create('Cannot monitor volume, because WAVECAPS_VOLUME is not supported.' );
  end;
  FCheckTimer := TTimer.Create(nil);
  FCheckTimer.OnTimer := CheckTimed;
  FCheckTimer.Interval := 0;
  FCheckTimer.Enabled := True;

  FAutoAdjustVolume := True;
  FTargetVolume := 100;
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
  CurrentVolume: TPercentage;
  AdjustVolume:  Boolean;
  Timestamp:     TDateTime;
begin
  if (CallWithErrorHandling('WaveOutGetVolume', WaveOutGetVolumePercentage(CurrentVolume))) then begin
    Timestamp := Now;
    if (CurrentVolume <> FTargetVolume) then begin
      AdjustVolume := FAutoAdjustVolume;
      if (Assigned(FOnTargetViolation)) then begin
         // Event handler can decide whether they want to let the violation
         // slide or even set TargetVolume to some new value.
         FOnTargetViolation(Self, CurrentVolume, AdjustVolume);
      end;
      if (AdjustVolume and (CurrentVolume <> FTargetVolume)) then begin
        CallWithErrorHandling('WaveOutSetVolume', WaveOutSetVolumePercentage(FTargetVolume));
      end;
      FLastViolation := Timestamp;
    end;
    FLastCheck := Timestamp;
  end;
end;

function TVolumeMonitor.CallWithErrorHandling(AOperation: string; AReturnCode: Cardinal): Boolean;
begin
  Result := AReturnCode = MMSYSERR_NOERROR;
  if (not Result) and Assigned(FOnError) then begin
    FOnError(Self, Format('%s failed. Error: %d', [AOperation, AReturnCode]));
  end;
end;

{ TVolumeMonitor - Getter/setter }

procedure TVolumeMonitor.SetCheckInterval(AValue: Cardinal);
begin
  FCheckTimer.Interval := AValue;
end;
    

end.