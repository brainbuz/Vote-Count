use 5.028;

my $text = qq/
"name"                      stage1  stage2  stage3  stage4  stage5  stage6  stage7
"rounds"                    round1  ------  round2  round3  round4  round5  round6
  "GOLDIE, William (SNP)"     1779 1204.00 1204.00 1204.00 1204.00 1204.00 1204.00
  "GRAHAM, Allan (Lab)"       1413 1413.00 1204.00 1204.00 1204.00 1204.00 1204.00
  "HOGG, Paddy (SNP)"          444  810.20  815.82  816.32  836.42  857.55  926.39
  "HOMER, Willie (SNP)"        653  783.58  792.45  792.87  819.18  832.46  916.95
  "MASTERTON, Donald (CICA)"   344  358.54  363.13  363.68  392.87  486.34    0.00
  "MCARTHUR, David (Con)"      225  228.88  232.13  232.41  235.75    0.00    0.00
  "MCVEY, Kevin (SSP)"         140  147.76  152.34  153.14    0.00    0.00    0.00
  "MUIR, Stephanie (Lab)"     1017 1044.47 1210.43 1204.00 1204.00 1204.00 1204.00
  "non-transferable"             0   24.57   40.70   44.58  118.77  226.65  559.67
/;

my @rows = ();

for my $row( split /\n/, $text ) {
  $row =~ s/("\w.*")//;
  my $newline = $1;
  my @rest = split /\s+/, $row;
  say "$newline " . join ( "\t", @rest) ;
}