use warnings; use strict; 
######DNA DISTRIBUTION JOBMAKER v1_0 ###################################################
#this is based on vers 0_7 and is altered to work with vbs frontend DiNA_jobmaker.vbs
#ARGV from vbs script is 0. source path, 1.first sheet 2. second sheet... 
# this should return an error to the user in the vbs but do that later.
#########################################################################################
my $error_string='';
#print "ARGV!!!!!!!!!!!!!!!  $ARGV[0]\n";
my $pathtofolder=shift(@ARGV);
my $pathtobackend="$pathtofolder"; ##<<<<<<<<<<<<<<<<<<<<fornow, change to location of backend
my @controls=('712','326','696','694','756','326','326','326');
sub OUT; #run once per dest plate
sub ADD6controlsandOUT; #run once per 6 dest plates, runs GWL subs below
sub WHOLEPLATE_GWL; # inputs - vol2transferperdest, source plate/well, destination plate/well1, dest plate/well2...
sub PARTNERS_GWL; #inputs: 8atatime:- vol2trans, sourceplate/well, destplate/well1, destplate/well2
sub EA_BATCH_WRITE_GWL;
#sub EA_BATCH_VOL;

#step 1 ID the different sheets from argument vector ############################################################
my $sourcefilename='Source.txt'; my %batches; my $gotaSourceSheet; my $gotaBatchSheet;

foreach my $sheet (@ARGV){ unless ($sheet ne ''){next}
  #print "sheet:$sheet\n";
  if ($sheet=~/Source.txt/ ){$gotaSourceSheet = 'yes';}# $sourcefilename = "$sheet";}
  if ($sheet=~/B(\d)_/){$gotaBatchSheet = 'yes'; $batches{$1}="$sheet"}
}
unless ($gotaSourceSheet){$error_string.= "dude I need a source sheet\n\r\a"; die "dude I need a source sheet\n\r\a";}
unless ($gotaBatchSheet){$error_string.= "dude I need at least one batch sheet\n\r\a"; die "dude I need at least one batch sheet\n\r\a"}

#step 2 make hash of alphanum 96 positions (A1-H12) to tecan pos(1-96) in  %letternumber96indices_toTecanindicies;
my $tecanpos96=0; my %letternumber96indices_toTecanindicies;
foreach my $numberincolumn96 (1..12){
    foreach my $letterrowin96 ('A'..'H'){
        $tecanpos96++;
        my $index=$letterrowin96.$numberincolumn96;
        $letternumber96indices_toTecanindicies{$index}=$tecanpos96;
        #print "$letternumber96indices_toTecanindicies{$index}*$index*$tecanpos96\n";
    }
}

#step3.1 make each dest template 1-4,triplicate pair locations in %pairs_template_positions, 
#also %which_plate_template_forplatenum
my $template = 1;  #plates 1-4
my %pairs_template_positions; #key is $platenum.$PPI => B4,B5,B6 (for example)
my %which_plate_template_forplatenum;
foreach my $platenum (1..500){ #this can go up to 500 dest plates, seems like plenty now
    my $PPI=1; my $startrowat;
    if ($template == 1 || $template == 2){ $startrowat = 4}  
    if ($template == 3 || $template == 4){ $startrowat = 1}
    foreach my $row ('A'..'H'){
        my $column=$startrowat;
        foreach my $PPIperRow (1..3){ # run loop 3x per row
            my $key="$platenum $PPI"; #<<<<<<<<<<<<<<<<<<KEY               
            $pairs_template_positions{$key}="$row$column";
            $column++; $pairs_template_positions{$key}.=",$row$column";
            $column++; $pairs_template_positions{$key}.=",$row$column";
            $column++;
            #print "$key => $pairs_template_positions{$key}\n";   
            $PPI++;   
        } 
    } 
    $which_plate_template_forplatenum{$platenum}=$template;#like plate 7 is template 3
    #print "$platenum=>$which_plate_template_forplatenum{$platenum}\n";
    $template++; if ($template==5){$template=1}
} #now we have plate# +PPInum => positions ( $pairs_template_positions{$platenum.$PPI})
# and  we have plate# => template# ($which_plate_template_forplatenum{$platenum})
#looks like 500 21 => H7,H8,H9 and 500=>4

#Step 3.2 load $sourcefilename and store source locations in %pos_hash
my %pos_hash; #keyed by name
open(my $fh2, '<:encoding(UTF-8)', $sourcefilename) or $error_string.= "Could not open file '$sourcefilename' $!";
<$fh2>; #skip fisrt line
while (my $row = <$fh2>) {
  $row=~s/\r//g;
  chomp $row; #chop $row; print "*$row*\n";chop $row; print "*$row*\n";
  my @elements=split(/,/, $row); 
  unless ($elements[0]){next} #skip empty lines
  unless ($elements[1]){die "0: $elements[0]\n 1:$elements[1] \n"}
  my $prot=$elements[0]; # $pos is like: 1,A1
  my $pos=$elements[1].",".$elements[2].$elements[3]; # $pos is like: 1,A1
  if ($pos_hash{$prot}){$error_string.= "warning: $prot present twice, overwriting first pos with $pos\n"}
  $pos_hash{$prot}=$pos; #print "PROT *$prot* POS *$pos*\n"; 
}

#step3.3 make dest templates for controls
#3 Assemble everyplate control pipetting parameters (locations, volume, name of control) per plate
# like this $newplateout{500}=(sourceplate,sourcepos,destplate,destpos,volume,name\n
#   nextsourceplate,sourcepos,destplate,destpos,volume,name\n... ) for plate 500
my %newplateout; #keyed by template
my $plate1to4=1;
for my $plate1to500 (1..500){
    #plate 1 is (A,C,E,G) * 123
    #plate 2 is (B,D,F,H) * 123
    #plate 3 is (A,C,E,G) * 101112
    #plate 4 is (B,D,F,H) * 101112
    # write generic template for controls (repeats w each new plate)
  my (@letters,@numbers)=('',''); $newplateout{$plate1to500}='';
  my @volumes=(5,5,5,5,5,5,5,5); #my @volumes=(10,5,5,10,10);
  if ($plate1to4==1 || $plate1to4==3){ @letters=('A','A','C','C','E','E','G','G');}
  if ($plate1to4==2 || $plate1to4==4){ @letters=('B','B','D','D','F','F','H','H');}
  #if ($plate1to4==1 || $plate1to4==3){ @letters=('A','C','C','E','G');}
  #if ($plate1to4==2 || $plate1to4==4){ @letters=('B','D','D','F','H');}
  if ($plate1to4==1 || $plate1to4==2){ @numbers=(1,2,3);}
  if ($plate1to4==3 || $plate1to4==4){ @numbers=(10,11,12);}
  foreach my $i (0..7){#foreach my $i (0..4){#print $i;
    my $letter = $letters[$i];
    my $prot = $controls[$i]; 
    my $volume =$volumes[$i];
    my $pos = "$pos_hash{$prot}";
    my $pl; if ($plate1to500<10){$pl="0$plate1to500"} else {$pl="$plate1to500"}
    $newplateout{$plate1to500}.="$pos,Dest$pl";
    foreach my $j (@numbers){ 
      #$newplateout{$plate1to500}.="$pos,Dest$pl,$letter"."$j,5,contains:CONTROL $prot\n"}
      $newplateout{$plate1to500}.=",$letter"."$j";
    }
    $newplateout{$plate1to500}.=",$volumes[$i],contains:CONTROL $prot\n";}
  #my $out="****$newplateout{1}*****"; #this string contains the CSV to print out. (contains prot name, remove for tecan)
  $plate1to4++;
  if ($plate1to4==5){$plate1to4=1}
}#print "*$newplateout{1}\n"; # <<<<<<<<<<USE THIS


#step 5 for each batch, determine plating instructions and volumes and add to cumulative volumes
my $size=keys(%batches);
my %wholeplate_parameters; my %partner_parameters; #keyed by plate AND $bbbase
my ($out,$plate_pipetting_parameters,$control_pipetting_parameters) =('','','');
my @platesout=();   my ($bbbase,$throwout);
foreach my $b (1..$size){
  EA_BATCH_WRITE_GWL($batches{$b});
  #EA_BATCH_VOL($batch{$b});
}

sub EA_BATCH_WRITE_GWL{ #<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
  my $destpairsfilename= $_[0];
  ($bbbase,$throwout) = split(/\./,$destpairsfilename);
  my $outgwlname = "$bbbase.gwl"; my $outgwlplus = "$bbbase"."_gwlplusextrainfo.xls"; 
  ($out,$plate_pipetting_parameters,$control_pipetting_parameters) =('','',''); #put plate printlines here and put in $out when next plate comes up
  @platesout=();
    
#Step 6 load file with final locations and add position data from %pos_hash,
    # find repeater,pass lines one plate ate a time to OUT
    my ($plate,$plate1to6,$plate1toFour) = (0,0,0); #start at 0, plate goes as high as in input

    my @rows = (); #rows for one entire plate here at a time;
    #the repeater will be pipetted first, then the others
    my ($repeater,$lastdonornum, $lastacceptornum)=("unknown", "unknown", "unknown");
    open(my $fh, '<:encoding(UTF-8)', $destpairsfilename)  or print "Could not open file '$destpairsfilename' $!"; <$fh>;
    while (my $row = <$fh>) { 
    chomp $row; #print "4:$plate $row\n";#print $out;
    my ($thisplate,$PPI,$donornum,$tag,$donorname,$acceptornum,$tag2,$acceptorname)=split(/,/,$row); #print "thisplate=$thisplate plate=$plate\n";
    #new plate? 
    if ($plate!=$thisplate){ #then it's the first line of the next plate
        #if($plate==1){$plate++;}
        unless($plate==0){OUT($plate,$repeater,$plate1to6,$plate1toFour,@rows);@rows = ()} #run OUT unless this is the first plate
        $plate++;
        $plate1to6++;if ($plate1to6==5){$plate1to6=1} #if ($plate1to6==7){$plate1to6=1} #six positions for destinations per run
        $plate1toFour++; if ($plate1toFour==5){$plate1toFour=1} #4 templates for destinations per run
        ($repeater,$lastdonornum, $lastacceptornum)=("unknown", "unknown", "unknown");
    }
    elsif ($repeater eq "unknown") {#find repeater
        if ($lastdonornum eq $donornum){$repeater="donor"}
        if ($lastacceptornum eq $acceptornum){$repeater="acceptor"}
        #$plate++;
    }
    elsif ($repeater eq "donor") {unless($lastdonornum eq $donornum){die "check donor in:\n $row"}}#check donor }
    elsif ($repeater eq "acceptor") {unless($lastacceptornum eq $acceptornum){die "check accetpor in:\n $row"}}#check acceptor}

    push (@rows,$row);  
    ($lastdonornum, $lastacceptornum)=($donornum, $acceptornum);
    #$plate1to6++; if ($plate1to6==7){$plate1to6=1} #six positions for destinations per run
    #$plate1toFour++; if ($plate1toFour==5){$plate1toFour=1} #4 templates for destinations per run
    } 
    $plate1to6=4;#6;
    OUT($plate,$repeater,$plate1to6,$plate1toFour,@rows);
    #and print it out!
    my $otherout = $out;
    $otherout=~s/,contains:.+\n/\n/g; #get rid of name labels for csv
    $out=~s/,/\t/g;

    open(my $fh3, '>', $outgwlname) or die ('did not open FH3');
    print $fh3 $otherout;
    close $fh3;

    #open(my $fh4, '>', $outgwlplus) or die ('did not open FH4');
    #print $fh4 $out;
    print "ERRORSifany:\n$error_string\n";
}

sub OUT{ 
  print "running OUT\n";
  foreach my $thing(@_){print "@ $thing\n"}
  my ($thisplate,$repeater,$plate1to6,$plate1toFour,@rows)=@_; 
  #print "BBBBASE $bbbase\n";
  #print "plate$thisplate, repeater$repeater, pl1-6$plate1to6, pl1-4$plate1toFour\n$rows[0]\n\n";#@rows";
  my $nonrep_pipetting_parameters=''; #nonrepeating lines stored here until 6th
  my $repeating_pipetting_parameters=''; 
  #my $control_pipetting_parameters;
  $wholeplate_parameters{"$thisplate$bbbase"}='';
  $partner_parameters{"$thisplate$bbbase"}='';
  foreach my $row (@rows){
    #print "THIS IS THE ROW $row\n";
    my ($thisplate,$PPI,$donornum,$tag,$donorname,$acceptornum,$tag2,$acceptorname)=split(/,/,$row);
    my $mod=$thisplate%6; if ($mod==0){$mod=6} #use with modified line below
    my $dest; $dest="Dest0$mod";#if ($plate<10){$dest="Dest0$thisplate"} else {$dest="Dest$thisplate"}
    my $p1; my $p2;
    if ($repeater eq 'donor'){$p1=$donornum;$p2=$acceptornum} else {$p2=$donornum;$p1=$acceptornum }
    my $key="$thisplate $PPI"; 
    unless ($p1 && $p2){$error_string.="missing protien plate: $thisplate PPI# $PPI\n"; next}
    unless ($pos_hash{$p1}){$error_string.="missing source for protien:$p1\n";next} 
    unless ($pos_hash{$p2}){$error_string.="missing source for protien:$p2\n";next} 
    my $p1pos="$pos_hash{$p1}"; #get source pos for both 
    my $p2pos="$pos_hash{$p2}"; #get source pos for both 
    #$nonrep_pipetting_parameters.="$pos_hash{$p2}".",$dest,$pairs_template_positions{$key},$p2\n"; 
    #$repeating_pipetting_parameters.=$pos_hash{"$p1"}.",$dest,$pairs_template_positions{$key},$p1\n";
    $wholeplate_parameters{"$thisplate$bbbase"}.="$p1pos,$dest,$pairs_template_positions{$key},$p1\n";  
    $partner_parameters{"$thisplate$bbbase"}.="$p2pos,$dest,$pairs_template_positions{$key},$p2\n"; 
    #$nonrep_pipetting_parameters.="$p2pos,$dest,$pairs_template_positions{$key},$p2\n"; 
    #$repeating_pipetting_parameters.="$p1pos,$dest,$pairs_template_positions{$key},$p1\n";  
  }
#$plate_pipetting_parameters.=$repeating_pipetting_parameters.$nonrep_pipetting_parameters;
#print "THIS PLATE $thisplate\n";
$control_pipetting_parameters.=$newplateout{$thisplate}; 
#$wholeplate_parameters{"$thisplate"}=$repeating_pipetting_parameters; 
#$partner_parameters{"$thisplate"}=$nonrep_pipetting_parameters;
push(@platesout,$thisplate);
if($plate1to6==4){ADD6controlsandOUT($bbbase)} #if($plate1to6==6){ADD6controlsandOUT($bbbase)}
}
#$out.=$repret.$rep.$nonrep; #non repeating lines on end  
#print $out;
#/////////////////////////666666666666666666666666666666666666666666666666666666666

sub ADD6controlsandOUT { #this adds control pipetting instructions for 6 plates
  #print "running ADD6controlsandOUT\n";
  #print "controls:\n$control_pipetting_parameters";
  my $bbbase=$_[0];
  my @controllines=split(/\n/,$control_pipetting_parameters);
  my %controls; my @passcontrols=();
  foreach my $line (@controllines){ 
    my ($sourcepl,$sourcepos,$destpl,$destpos1,$destpos2,$destpos3,$vol,$contains)=split(/,/,$line);
    $destpl=~/Dest(..)/;
    my $destplnum=$1; 
    #my $dest1to6=$destplnum%6; if($dest1to6==0){$dest1to6=6}
    my $dest1to6=$destplnum%4; if($dest1to6==0){$dest1to6=4}
    $destpl="Dest0$dest1to6";
    my ($Tdestpos1,$Tdestpos2,$Tdestpos3)=($letternumber96indices_toTecanindicies{$destpos1},$letternumber96indices_toTecanindicies{$destpos2},$letternumber96indices_toTecanindicies{$destpos3}) ;
    unless ($controls{$contains}){$controls{$contains}="$vol,$sourcepl,$sourcepos,$destpl"."_$Tdestpos1,$Tdestpos2,$Tdestpos3";}
    else {$controls{$contains}.=",$destpl"."_$Tdestpos1,$Tdestpos2,$Tdestpos3";}
    }
  #print "THIS IS MY KEY: $contains\n";
  #push(@passcontrols,$controls{"contains:CONTROL 326"});
  foreach my $key (keys(%controls)){ 
    $controls{$key}=~s/\r//g;
    if ($key eq "contains:CONTROL 326"){next}
    push(@passcontrols,$controls{$key});
    #print "*$key****$controls{$key}\n*";
  }
  $out.=PARTNERS_GWL($controls{"contains:CONTROL 326"});
  $out.=PARTNERS_GWL(@passcontrols);
  $control_pipetting_parameters='';###########<<<<<<<<<<<<<<<<<<<new

#now the whole plate PPI partners
  my $pass;
  foreach my $pl (@platesout){
    #print "plate whole $pl\n";
    #print $wholeplate_parameters{"$pl$bbbase"}."\n";
    #my %lines; my @passlines=();
    my @wlines=split(/\n/,$wholeplate_parameters{"$pl$bbbase"});
    foreach my $line (@wlines){ 
      my ($sourcepl,$sourcepos,$destpl,$destpos1,$destpos2,$destpos3,$contains)=split(/,/,$line);
      #my ($Tdestpos1,$Tdestpos2,$Tdestpos3)=($letternumber96indices_toTecanindicies{$destpos1},$letternumber96indices_toTecanindicies{$destpos2},$letternumber96indices_toTecanindicies{$destpos3});
      unless ($pass){$pass="5,$sourcepl,$sourcepos,$destpl,$destpos1,$destpos2,$destpos3";}
      else {$pass.=",$destpos1,$destpos2,$destpos3";}
    }
    #print "PASS=***$pass***\n";
    my @pass=split(/,/,$pass);
    $out.=WHOLEPLATE_GWL(@pass);
    $pass='';
#now the nonrep partners
    #print "plate parnters$pl\n";
    #print $partner_parameters{"$pl$bbbase"}."\n";
    @pass=(); $pass=();
    my @lines=split(/\n/,$partner_parameters{"$pl$bbbase"});
    my $j=1;
    foreach my $i (0..$#lines){ 
      my ($sourcepl,$sourcepos,$destpl,$destpos1,$destpos2,$destpos3,$contains)=split(/,/,$lines[$i]);
      my ($Tdestpos1,$Tdestpos2,$Tdestpos3)=($letternumber96indices_toTecanindicies{$destpos1},$letternumber96indices_toTecanindicies{$destpos2},$letternumber96indices_toTecanindicies{$destpos3}) ;
      push(@pass,"5,$sourcepl,$sourcepos,$destpl"."_$Tdestpos1,$Tdestpos2,$Tdestpos3");
      #else {$pass.=",$destpos1,$destpos2,$destpos3";}
      if ($i==$#lines){ $out.=PARTNERS_GWL(@pass); @pass=() }
      elsif ($j==8) {  $out.=PARTNERS_GWL(@pass); @pass=();$j=1}
      $j++
    }
  }
  #$out.=$plate_pipetting_parameters;
  #$out.=$control_pipetting_parameters;
    $out.="BREAK_NEXT_JOBLIST\n";#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<uncomment if I want breaks again
  $plate_pipetting_parameters='';
  $control_pipetting_parameters='';
  @platesout=();
} #

#my %partner; 
#$partner{k1}="5,2,B1,dest01_B4,B5,B6,dest02_B4,B5,B6";
#$partner{k2}="5,2,C1,dest01_C4,C5,C6,dest02_C4,C5,C6";
#PARTNERS_GWL("k1","k2"); #up to 8 partners
sub PARTNERS_GWL{
  #print "running PARTNERS_GWL\n";
    my $return='';
    my @lines = @_;
    my @tipbit = (1,2,4,8,16,32,64,128); my $i=0;
    foreach my $l (@lines){ #one key per partner DNA 
        my ($dispvol,$sourceplate,$swell,@dest)=split(/\,/,$l); #dest are like "dest01,'B4','B5','B6','B7'.."
        my $sourcewell=$letternumber96indices_toTecanindicies{$swell};
        my ($LIQclass,$LIQclass_backtosource)=("Water dry contact DiNa rearray","Water wet contact");
        my $destplate; #=split(/_/,$dest[0]);
        #my @rowletters=qw/A B C D E F G H/;
        #$tecanpos=$letternumber96indices_toTecanindicies{$position};
        
        my $aspvolume=$dispvol*@dest+10;#5 extra uL, 5 for 1st dispense back to source
        if ($aspvolume>99){ $aspvolume += 5} elsif ($aspvolume>199){$aspvolume += 7 } elsif ($aspvolume>299){$aspvolume += 10 }
        my $displines=''; 
        my $aspline="A;;$sourceplate;MDC96Well DeepWell;$sourcewell;;$aspvolume;$LIQclass;;$tipbit[$i]\n".
        "D;;$sourceplate;MDC96Well DeepWell;$sourcewell;;$dispvol;$LIQclass_backtosource;;$tipbit[$i]\n"; #first to source
        foreach my $col (0..$#dest){
            my $destposition = shift(@dest); #$letters[$i].$col; 
            if ($destposition=~/_/){($destplate,$destposition)=split(/_/,$destposition);}
            #my $tecanpos=$letternumber96indices_toTecanindicies{$position};
            $displines.= "D;;$destplate;MDC96 Black MTP with LID;$destposition;;$dispvol;$LIQclass;;$tipbit[$i]\n";
            #print "D;;$destplate;MDC96 Black MTP with LID;$tecanpos;;$dispvol;$liqclass;;$tipbit\n";
            }
        #my $return= "A;;$sourceplate;MDC96Well DeepWell;$tecanpos;;$aspvolume;$liqclass;;$tipbit\n"
        $return.= $aspline . $displines . "W;\n"; #$return.= $aspline . $displines . "W;\n";
        $i++;
    }
    $return.= "B;\n"; #$return.= "B;\n";
    #print $return;
    return $return;
}

#WHOLEPLATE_GWL(5,"2","B1","dest01",'B4','B5','B6','B7','B8','B9','B10','B11','B12','C4','C5','C6','C7','C8','C9','C10','C11','C12','D4','D5','D6');
sub WHOLEPLATE_GWL{ #500 21 => H7,H8,H9 
  #print "running WHOLEPLATE_GWL\n";
    my $return='';
    my ($dispvol,$sourceplate,$swell,@dest)=@_; #dest are like "dest01,'B4','B5','B6','B7'.."
    my $sourcewell=$letternumber96indices_toTecanindicies{$swell};
    my ($LIQclass,$LIQclass_backtosource)=("Water dry contact DiNa rearray","Water wet contact");
    my $destplate=shift(@dest);
    my @rowletters=qw/A B C D E F G H/;
    my %row_destinations; #keyed by rowletter
    foreach my $dest(@dest){#lets split into rows into $rowdestinations{$letter}
        my $letter = substr($dest,0,1);
        unless ($row_destinations{$letter}){$row_destinations{$letter}.=$dest;}
        else {$row_destinations{$letter}.=",$dest"; }
    }
    my $i =0; #increments for each row
    #my $position=1;my @positions=1; #keeping strict gods happy
    #my $tecanpos=1;
    my @letters=qw/A B C D E F G H/;
    foreach my $tipbit (1,2,4,8,16,32,64,128){
        my $letter = $letters[$i]; #print "$letter $i\n";
        unless($row_destinations{$letter}){$i++;next} #skip loop if nothing to pipette
        #$tecanpos=$letternumber96indices_toTecanindicies{$position};
        my @destwells=split(/,/,$row_destinations{$letter});
        my $aspvolume=$dispvol*@destwells+10;#5 extra uL, 5 for 1st dispense back to source
        my $displines=''; 
        my $aspline="A;;$sourceplate;MDC96Well DeepWell;$sourcewell;;$aspvolume;$LIQclass;;$tipbit\n".
        "D;;$sourceplate;MDC96Well DeepWell;$sourcewell;;$dispvol;$LIQclass_backtosource;;$tipbit\n"; #first to source
        foreach my $col (1..@destwells){
            my $destposition = shift(@destwells); #$letters[$i].$col;
            $destposition=$letternumber96indices_toTecanindicies{$destposition}; 
            #unless ($destposition){next} #skip if nothing in well.
            #my $tecanpos=$letternumber96indices_toTecanindicies{$position};
            $displines.= "D;;$destplate;MDC96 Black MTP with LID;$destposition;;$dispvol;$LIQclass;;$tipbit\n";
            #print "D;;$destplate;MDC96 Black MTP with LID;$tecanpos;;$dispvol;$liqclass;;$tipbit\n";
            }
        #my $return= "A;;$sourceplate;MDC96Well DeepWell;$tecanpos;;$aspvolume;$liqclass;;$tipbit\n"
        $return.= $aspline . $displines . "W;\n";#$return.= $aspline . $displines . "W;\n";
        $i++;
    } 
    $return.= "B;\n"; #$return.= "B;\n";
    #print $return;
    return $return;
}

__END__

