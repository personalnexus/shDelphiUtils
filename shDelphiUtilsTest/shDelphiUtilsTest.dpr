program shDelphiUtilsTest;

{$APPTYPE CONSOLE}

uses
  QueuesTest in 'QueuesTest.pas',
  SetsTest in 'SetsTest.pas';

begin
  ReportMemoryLeaksOnShutdown := True;

  QueuesTest.Run;
  SetsTest.Run;

  Writeln;
  Writeln('Finished. Press Enter to exit.');
  Readln;
end.
