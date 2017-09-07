uses                                                                                 
  Classes, Graphics, Controls, Forms, Dialogs, formaKryesore;

var                         
  frmPrintimi: TPrintimiFrm;              
  i:Integer;
begin
  frmPrintimi := TPrintimiFrm.Create(Application);                               
  frmPrintimi.Parent := FrmMain.tsInformations; 
  For i:=1 to FrmMain.nb1.PageCount-1 do FrmMain.nb1.Pages[i].TabVisible:=False;
  frmPrintimi.Show; 
end;                                                                                 
