use warnings; use strict;
#Update: calcvol3.pl, it adds 100 to partners, 150 to whole plate DNA and 150 to controls
#if the pattern of distribution is not all 25s or all 55s or it's not a control, 
#the program will give errors in the output 
#prompting the user to reevaluate a distribution pattern as partner or whole plate 

my $sourcefilename = $ARGV[0];
my $outgwlname = "all.gwl"; 
#my $sourcefilename = "HDAC_source.txt";
#my $outgwlname = "pipettingHDAC.gwl"; 

my @gwllines=`cat $outgwlname`;
my %vol; my %totalvol;
foreach my $line (@gwllines){
    #print "my $line";
    unless ($line=~/^A/){next}
    my @elements=split(/;/,$line);
    my ($plate,$well,$vol)=($elements[2],$elements[4],$elements[6]);
    #print "pl$plate,we$well,vol$vol\n";
    my $key="$plate$well";
    unless($vol{$key}){$vol{$key}=$vol} else {$vol{$key}.="_$vol"}
    unless($totalvol{$key}){$totalvol{$key}=$vol} else {$totalvol{$key}+=$vol}
}

# make a hash of 96 to the tecan positions
my $tecanpos96=0; my %letternumber96indices_toTecanindicies;
foreach my $numberincolumn96 (1..12){
    foreach my $letterrowin96 ('A'..'H'){
        $tecanpos96++;
        my $index=$letterrowin96.$numberincolumn96;
        $letternumber96indices_toTecanindicies{$index}=$tecanpos96;
        #print "$letternumber96indices_toTecanindicies{$index}*$index*$tecanpos96\n";
    }#good it works.
}

my @sourcelines=`cat $sourcefilename`;
my $header=shift(@sourcelines);   chomp $header; chop $header;
print "$header,noDeadVol,add,predictedVolReq,DistrPattern\n";
foreach my $lline (@sourcelines){
    chomp $lline; # print "$lline\n";
    $lline =~ s/\r//g;
    my ($sample,$plate,$row,$col)=split(/,/,$lline);
    my $pos ="$row$col";
    my $Tpos=$letternumber96indices_toTecanindicies{$pos};
    my $kkey="$plate$Tpos"; 

    my $IScontrol=0;
    if ($sample == 696){ $IScontrol='yes'} 
    if ($sample == 694){ $IScontrol='yes'} 
    if ($sample == 756){ $IScontrol='yes'} 
    if ($sample == 712){ $IScontrol='yes'} 
    if ($sample == 326){ $IScontrol='yes'} 
    my $ISwholeplate=0;
    my $ISpartner=0; #in case there's a distribution pattern I haven't accounted for
    my @vols=split(/_/,$vol{$kkey}); 
    my $firstvol = $vols[0]; my $different;
    #
    foreach my $v (@vols){ if ($firstvol!=$v){$different='different'}}
    unless ($different){if ($firstvol == 25){ $ISpartner='partner'} }
    unless ($different){if ($firstvol == 55){ $ISwholeplate='wholeplate'} }

    my $addvol = 'warning'; my $predictedvol= 'check_pattern_of_distribution';
    if ($IScontrol){ $addvol = 150; $predictedvol=$addvol+$totalvol{$kkey}}
    if ($ISpartner){ $addvol = 100; $predictedvol=$addvol+$totalvol{$kkey}}
    if ($ISwholeplate){ $addvol = 150; $predictedvol=$addvol+$totalvol{$kkey}}


    print "$sample,$plate,$row,$col,$totalvol{$kkey},$addvol,$predictedvol,$vol{$kkey}\n"

}