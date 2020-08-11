program shDelphiUtilsTest;

{$APPTYPE CONSOLE}

uses
  QueuesTest in 'QueuesTest.pas',
  SetsTest in 'SetsTest.pas',
  CommonTest in 'CommonTest.pas',
  KeyValueListsTest in 'KeyValueListsTest.pas',
  TriesTest in 'TriesTest.pas';

begin
  ReportMemoryLeaksOnShutdown := True;

  CommonTest.Run;
  KeyValueListsTest.Run;
  QueuesTest.Run;
  TriesTest.Run;
  SetsTest.Run;

  Writeln;
  Writeln('Finished. Press Enter to exit.');
  Readln;
end.
