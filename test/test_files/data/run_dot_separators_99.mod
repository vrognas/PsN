$PROB  DUMMY FROM THEOPHYLLINE
$INPUT      ID DOSE=AMT TIME DV WT TEST SEP1 SEP2 SEP3 SEP4 LIM1 LIM2 C6 C5 C4 C3 C2 C1 C0
$DATA       test_dot_separators_99.dta

$SUBROUTINES  ADVAN2

$PK
;THETA(1)=MEAN ABSORPTION RATE CONSTANT (1/HR)
;THETA(2)=MEAN ELIMINATION RATE CONSTANT (1/HR)
;THETA(3)=SLOPE OF CLEARANCE VS WEIGHT RELATIONSHIP (LITERS/HR/KG)
;SCALING PARAMETER=VOLUME/WT SINCE DOSE IS WEIGHT-ADJUSTED
   CALLFL=1
   KA=THETA(1)+ETA(1)
   K=THETA(2)+ETA(2)
   CL=THETA(3)*WT+ETA(3)
   SC=CL/K/WT


$THETA  (.1,3,5) (.008,.08,.5) (.004,.04,.9)
$OMEGA BLOCK(3)  6 .005 .0002 .3 .006 .4

$ERROR
   Y=F+EPS(1)

$SIGMA  .4

$TABLE  FORMAT=sF6.0 FILE=answer_dot_separators_99.dta NOPRINT NOAPPEND NOHEADER TEST SEP1 SEP2 SEP3 SEP4 LIM1 LIM2 C0
