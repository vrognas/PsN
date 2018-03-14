$PROBLEM  PHENOBARB
$INPUT  ID TIME AMT WGT APGR DV
$DATA  pheno.dta IGNORE=@ IGNORE=(WGT.EQN.3)
$SUBROUTINE  ADVAN1 TRANS2
$PK
      TVCL=THETA(1)
      TVV=THETA(2)
      CL=TVCL*EXP(ETA(1))
      V=TVV*EXP(ETA(2))
      S1=V
$ERROR
      W=F
      Y=F+W*EPS(1)
      IPRED=F
      IRES=DV-IPRED
      IWRES=IRES/W

$THETA (0,0.0105)
$THETA (0,1.0500)
$OMEGA .4 .25
$SIGMA .04                         
$ESTIMATION  MAXEVALS=9997 SIGDIGITS=4 POSTHOC
