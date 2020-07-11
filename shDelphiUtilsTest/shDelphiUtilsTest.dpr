program shDelphiUtilsTest;

{$APPTYPE CONSOLE}

uses
  QueuesTest in 'QueuesTest.pas',
  SetsTest in 'SetsTest.pas',
  CommonTest in 'CommonTest.pas';

begin
  ReportMemoryLeaksOnShutdown := True;

  CommonTest.Run;
  QueuesTest.Run;
  SetsTest.Run;

  Writeln;
  Writeln('Finished. Press Enter to exit.');
  Readln;
end.
