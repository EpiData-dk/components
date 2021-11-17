{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit ChsDet;

{$warn 5023 off : no warning about unused units}
interface

uses
  Big5Freq, CharDistribution, chsdIntf, CustomDetector, EUCKRFreq, EUCSampler, 
  EUCTWFreq, GB2312Freq, JISFreq, JpCntx, MBUnicodeMultiProber, 
  MultiModelProber, nsCodingStateMachine, nsCore, nsEscCharsetProber, 
  nsGroupProber, nsHebrewProber, nsLatin1Prober, nsMBCSMultiProber, nsPkg, 
  nsSBCharSetProber, nsSBCSGroupProber, nsUniversalDetector, 
  LangBulgarianModel, LangCyrillicModel, LangGreekModel, LangHebrewModel, 
  LazarusPackageIntf;

implementation

procedure Register;
begin
end;

initialization
  RegisterPackage('ChsDet', @Register);
end.
