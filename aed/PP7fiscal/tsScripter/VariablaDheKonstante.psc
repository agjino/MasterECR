{Variablat e printimit te artikullit }                                                 
Var
      ArtPershkrim,{ Pershkrimi i artikullit } 
      ArtCmimi,       { eshte cmimi i nje artikulli te vetem (-999999.99 deri 999999.99)
                        cmimi negativ perdoret per te anulluar shitjen }               
      ArtSasia,       { Sasia e shitjes nga 0 deri 99999.999 }    
      ArtTarifa,      { Numri i takses (TVSH-se) nga 1 deri 9 }
      ArtTipShitje,   { 1 - Artikulli kthehet 
                        0 - Artikulli shitet }
      ArtTipNdryshimVlere,          
                   { 0 - mbingarkim  ne perqindje ( max 99.00% )
                     1 - zbritje ne perqindje ( max 99.00% ) 
                     2 - mbingarkim ne vlere ( max 8 shifror )
                     3 - zbritje ne vlere ( max 8 shifror )       }
      ArtVlera     { Vlera e Zbritjes/Mbingarkimit ne veresi te [TipNdryshimVlere] } 
                 : String;
 {-------------------------------------------------------------------------------------}  
