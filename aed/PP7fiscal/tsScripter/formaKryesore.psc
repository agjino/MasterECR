{$FORM TPrintimiFrm, formaKryesore.sfm}                                           

uses
  Classes, Graphics, Controls, Forms, Dialogs, StdCtrls, 
  ExtCtrls, ComCtrls, DB, DBTables, Grids, DBGrids, VariablaDheKonstante, SysUtils ;     
  
Var i, iSelected : integer;
    Art:TStringList;  
    bUpagua, bKaArtikuj, bKaVlere, bUHapFatura, bUMbyllFatura : Boolean;
    
{ indeksin nga nje StringList nese ekziston -----------------------------------}    
Function StringNgaLista(Lista:TStringList; Indeksi : Integer; 
                                                DefaultValue:String ) : String;
Begin
 Result:=DefaultValue;    
 if Lista.Count >= Indeksi+1 Then Result := Lista[indeksi]; 
 if Trim(Result) = '' Then Result := DefaultValue;
End;                            
   
{Gjejme kodin e komandes-------------------------------------------------------}
Function GjejKomande(sKomanda:String) : Integer;
Var sSimboli : String;
    iPoz     : String;
Begin
 Result:=-1; 
 iPoz := Pos(',',sKomanda);         
 sSimboli := Copy(sKomanda,1, iPoz-1);
 If dtConfig.Locate('Simboli', sSimboli, 0 ) then     
     Result := dtConfig.FieldByName('Kodi').AsInteger;
End;                                           

{Hapje Fature ----------------------------------------------------------------}
Function F_48(sKomanda : String ) : String;  
var
  s:string; 
  sUser,sPassword,sFatura : String;
begin       
   Art.Delimiter := ';';                                                      
   Art.StrictDelimiter := True;
   Art.DelimitedText := sKomanda ; 
   sUser        := StringNgaLista(Art,0,'0');   
   sPassword    := StringNgaLista(Art,1,'0');   
   sFatura      := StringNgaLista(Art,2,'');
   if sUser = '0' then sUser := IntToStr(FrmMain.seOperator_ID.Value);
   if sPassword = '0' then sPassword := FrmMain.edOP_Password.Text;
  if Trim(sFatura) = '0' then sFatura := '';
  if Trim(sFatura)<>'' then
    s:=Format('%s,%s,I%s',[sUser,spassword,sFatura])
  else                        
    s:=Format('%s,%s',[sUser,spassword]);
  Result := S;    
  bUHapFatura :=   True;
End;

{ Pergatit rreshtin e printimit te artikullit ---------------------------------}
Function F_49(sKomanda : String ) : String;  
Var S, S1 : String;
    xVlera:Double;
Begin                                                                        
   Art.Delimiter := ';';    
   Art.StrictDelimiter := True;   
   Art.DelimitedText := sKomanda ;                
   ArtPershkrim := StringNgaLista(Art,0,'Artikull pa emer '); 
   ArtCmimi     := StringNgaLista(Art,1,'0');   
   
   ArtSasia     := StringNgaLista(Art,2,'1');
   //ArtSasia     := FormatFloat(StrToFloat(ArtSasia),0); 
   ArtTarifa    := StringNgaLista(Art,3,'1');   
   ArtTipShitje := StringNgaLista(Art,4,'');   
   ArtTipNdryshimVlere                                                  
                := StringNgaLista(Art,5,'0');
   ArtVlera     := Trim(StringNgaLista(Art,6,'0'));    
             
  xVlera := StrToFloat( ArtCmimi );// FormatFloat(StrToFloat( ArtCmimi ),0);  
  //ArtCmimi := xVlera;                
  if StrToFloat( ArtCmimi ) < 0 then  
   Begin                                    
     xVlera   := StrToFloat( ArtCmimi ) * StrToFloat( ArtSasia );                       
     ArtCmimi := Floattostr(xVlera);// FormatFloat(xVlera,0)+'.00' ;
   End;  
  { Rikthim malli (Refund) }

  If ArtTipShitje = '0' then ArtTipShitje := 'R' else ArtTipShitje := '';  
  
  {               
    SQARIM : Anullimi i mallit ndodh nese cmimin e dergojme si vlere negative
    Nuk do te behej printimi nese edhe [Cmimi eshte Negativ] edhe [ArtTipShitje = '1'] 
  }

  //Ndertimi i komandes per printim te artikullit
  { <Name><Tab><Dept><Tab><[Type]Price>[*Qwan][,Perc\;Abs] }
  if xVlera<0 then  
  s:= ArtPershkrim + #9 + ArtTarifa + #9 + ArtTipShitje + ArtCmimi 
  else
  s:= ArtPershkrim + #9 + ArtTarifa + #9 + ArtTipShitje + ArtCmimi + '*' + ArtSasia ;

  if (ArtVlera <> '0') and (xVlera<0) then         
  Case StrToInt(ArtTipNdryshimVlere) OF
    0 : S := S + ',' + ArtVlera +'%';
    1 : Begin
         If Pos('.',ArtVlera)<=0 Then ArtVlera := ArtVlera+'.00';
         S := S + ';' + ArtVlera;
        End; 
  End;        
  Result := S;  
  bKaArtikuj := True;
End;  
                                   
{ Pergatit rreshtin per SUBTOTAL  --------------------------------------------}
Function F_51(sKomanda : String ) : String;  
Var S, S1 : String;
    sPrint, sDisplay, sTipSkonto, sVleraSkonto :String;
Begin           
   Art.Delimiter := ';';   
   Art.StrictDelimiter := True;   
   Art.DelimitedText := sKomanda ;                
   sPrint       := StringNgaLista(Art,0,'1');   
   sDisplay     := StringNgaLista(Art,1,'1');   
   sTipSkonto   := StringNgaLista(Art,2,'0');
   sVleraSkonto := Trim(StringNgaLista(Art,3,'0')); 
   
  { <Print><Display>[,Perc|;Abs] }
  s := sPrint+sDisplay {Printo subtotalin ne printer dhe ne display}   
  if sVleraSkonto <> '0' then         
  Case StrToInt(sTipSkonto) OF     
    0 : S := S + ',' + sVleraSkonto +'%';
    1 : Begin
         If Pos('.',sVleraSkonto)<=0 Then sVleraSkonto := sVleraSkonto+'.00';
         S := S + ';' + sVleraSkonto;
        End; 
  End;
  Result := S;
  //ShowMessage( Rezultati );
End;      

{PAGESA dhe menyra e pageses --------------------------------------------------}
Function F_53(sKomanda:String):String;
var
  s,s1: string;
  iMenyra : Integer;
  sVlera  : String;
begin     
   Art.Delimiter := ';';  
   Art.StrictDelimiter := True;   
   Art.DelimitedText := sKomanda ; 
  s:='';
  iMenyra      := StrToInt(StringNgaLista(Art,0,'0'));   
  sVlera       := StringNgaLista(Art,1,'');    
             
  case iMenyra of
    0: s:= s + #9 + 'P'; 
    1: s:= s + #9 + 'P' //'N';                     
    2: s:= s + #9 + 'P' //'C'; 
    3: s:= s + #9 + 'P' //'F'; 
    4: s:= s + #9 + 'P' //'G';
    5: s:= s + #9 + 'P' //'H';
    6: s:= s + #9 + 'P' //'I'; 
    7: s:= s + #9 + 'P' //'J'; 
    8: s:= s + #9 + 'P' //'K'; 
  end;        
  s1:=sVlera;  
  if (pos('.' ,s1) <=0) and (s1<>'') then s1:=s1+'.00';
  s:= s + s1;                             
  Result := S;
  bUpagua := True;
End; 

Function Eshte_F_53(sKomanda:String):Boolean;
var
  s,s1: string;
  iMenyra : Integer;
  sVlera  : String;
begin     
   Result:=False;
   Art.Delimiter := ';';  
   Art.StrictDelimiter := True;   
   Art.DelimitedText := sKomanda ; 
   s:='';
   iMenyra      := StrToInt(StringNgaLista(Art,0,'0'));   
   sVlera       := StringNgaLista(Art,1,'');  
   
   if (Trim(sVlera) = '') then sVlera := '0';
   if iMenyra = 4 then Result:=True;   
   if StrToFloat( sVlera ) <> 0  then Result := True;  
  
End;  

procedure TestoLidhjen(Sender: TObject);
begin
 FrmMain.btnLidhPrinter.Click; 
 infoLidhurShape.Brush.Color := FrmMain.shpLidhur.Brush.Color;
end;


procedure frmPrintimiCreate(Sender: TObject);                                 
begin   
  dtConfig.close;
  dtConfig.FileName := PathApplication + 'Protokoll.cfg';
  dtConfig.Open;
  {Me duhet per te ndare vlerat e rreshtit te artikullit qe shitet}
  Art := TStringList.Create;

  i:=0;
  Timer1.Enabled:=True;  
  dtConfig.Active:=True;  
  
end;                                                        


procedure PrintimiFrmClose(Sender: TObject; var Action: TCloseAction);
begin 
  action:=caFree;
end;

Procedure AddCommand(iKodi : Integer; sKomanda : String) ;
Begin
   listKodi.Items.Add( IntToStr(iKodi));
   listKomanda.Items.Add( sKomanda );
   mOutput.Lines.Add(sKomanda);             
End;                                        

procedure PerpunoTekstin(Sender: TObject);                  
Var i, iPoz : Integer;      
    Rresht : String;          
    sKomanda : String ; {Komanda e printimit}                  
    iKodi    : Integer; {Kodi i protokollit}
begin    
  mOutput.Lines.Clear; 
  listKomanda.Items.Clear;
  listKodi.Items.Clear;
  
  bUHapFatura   := False;
  bUpagua       := False; 
  bUMbyllFatura := False;
  bKaVlere      := False;
  bKaArtikuj    := False;
  
  for i:= 0 to mInput.Lines.Count-1 Do
   Begin      
     Rresht := Trim(mInput.Lines[i]);   

     {
     iPoz     := Pos(',', Rresht );
     sKodi    := Copy( Rresht, 1, iPoz-1 );
     }   
     iKodi    := GjejKomande(Rresht);
     iPoz     := Pos(';', Rresht );    
     
     sKomanda := Copy( Rresht, iPoz+1, length(Rresht) ); 
     
     if (iKodi = 56) then  
       Begin
        if Eshte_F_53( sKomanda ) then iKodi := 53;
       End; 
                                  
     if iKodi<>-1 then
     Begin
       Case iKodi of 
           48 : Begin 
                 bUHapFatura := True;
                 sKomanda := F_48(sKomanda);   {Hapje fature}                
                End;
           49 : Begin
                 if not bUHapFatura then Begin AddCommand(48,'1,'); bUHapFatura:=True; end;
                 sKomanda := F_49(sKomanda);   {Rresht artikulli} 
                End; 
           51 :  sKomanda := F_51(sKomanda);   {Nentotal}   
           53 : Begin 
                 bUpagua := True;
                 sKomanda := F_53(sKomanda);   {Pagesa}
                End; 
           56 :Begin    
                 if not bUpagua then Begin AddCommand(53,''); bUpagua := True; End;
                 bUMbyllFatura := True;
                End;
       End; 
      AddCommand(iKodi, sKomanda); 
     End;  
                                      
   end;   
   if not bUpagua then AddCommand(53,'');        
   if not bUMbyllFatura then AddCommand(56,'');     
End;
                                
procedure btPrintoClick(Sender: TObject);  
Var i:Integer;
begin   

 {Bej lidhjen me printerin fiskal nese nuk eshte i hapur}
 if not FiscalIsActive then FiscalOpen; 
 
 For i := 0 To listKodi.Items.Count - 1 do
   Begin                                     
    SendTxt( listKomanda.Items[i] , StrToInt( listKodi.Items[i] ) );
   End;
end;

procedure Sh1Click(Sender: TObject);
begin
  mInput.Lines.Text := TButton(Sender).Hint;
end;

procedure listKodiDblClick(Sender: TObject);
begin
  SendTxt( listKomanda.Items[iSelected] , StrToInt( listKodi.Items[iSelected] ) );
end;

procedure listKodiClick(Sender: TObject);
begin
  iSelected := ListKodi.ItemIndex;   
  
end;
                                                                            
procedure Timer1Timer(Sender: TObject); 
 
begin                                                  
  If FileExists( FrmMain.edSkedariInput.Text) then 
    Begin                                       
     mInput.Lines.LoadFromFile( FrmMain.edSkedariInput.Text ) ;      
     DeleteFile(FrmMain.edSkedariInput.Text );
     PerpunoTekstin(nil);
     btPrintoClick(nil);
    End;
  {
  inc(I);
  Label1.Caption := Self.Name+' '+ IntToStr(i)+ ' sekonda';
  FrmMain.Caption := Label1.Caption;
  }
end;

begin
end;
