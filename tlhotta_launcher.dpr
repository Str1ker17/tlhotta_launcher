program tlhotta_launcher;

uses
  Forms,
  FormMain in 'FormMain.pas' {Form1};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'TLHOTTA Launcher';
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.