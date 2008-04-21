
#
# script to generate dataless seed using mk_dataless_seed,
#   send it to the DMC via orbxfer2,
#   and track changes in a database
#
# J.Eakins
# 2/2008 
#


use Datascope ;
use archive;
require "getopts.pl" ;
use File::Path;
use Cwd;
 
elog_init ( $0, @ARGV) ;

our ($opt_d, $opt_m, $opt_p, $opt_v, $opt_V, $opt_s, $opt_o, $opt_f, $opt_z, $opt_C) ;
my ($now, $t) ;
my ($pgm,$mailtmp,$host);

if ( ! &Getopts('Dvzp:d:s:m:N:o:V:C:') || @ARGV < 2 || @ARGV > 4) { 
    die ( "Usage: $pgm [-v] [-z] [-p pf] [-d output_dir] [-C product_dir] [-N net] [-s sta] [-f output_file] [-m email1,email2,...] [-o orb] { -D | -V vnet } dbin dbtrack [comment] \n" ) ; 
} else {
    $dbin	= $ARGV[0];
    $dbtrack	 = $ARGV[1];
    if (@ARGV == 3) {
	$comment = $ARGV[2] ;
    }
}

$mycwd = getcwd();

$now	= time();
$t	= strtime($now);

$year	= epoch2str($now, "%Y");
$month	= epoch2str($now, "%m");
$day  	= epoch2str($now, "%d");

my $pgm = $0 ; 
$pgm =~ s".*/"" ;
$mailtmp = "/tmp/#$pgm.$$" if $opt_m;
   
chop ($host = `uname -n` ) ;

elog_notify(0,"\nStarting $pgm at: $t");

#elog_notify(&cmdline()) ;
&cmdline() if $opt_m;

elog_notify(0,"Current working directory: $mycwd\n");

elog_notify(0,"Reading pf file\n") if $opt_v;

if ($opt_p) {
   $pf = $opt_p;
} else {
   $pf = $pgm . ".pf" ;
}

if ($opt_s) {
   $sta = $opt_s ;
   elog_die("Can't use -s with -V\n") if $opt_V ;
}

if ($opt_V) {
   $vnet = $opt_V ;
}

if ($opt_v) {
   $opt_v = "-v";
}

if ( (!$opt_D && !$opt_V) || ( $opt_D && $opt_V) ) {
   elog_die("Must specify either -D or -V vnet. \n") ;
} 

&get_pf ;


if ($opt_s) {
   $STADLdir = $STADLdir . "/" . $sta  ;	# this forces single station dataless into a station directory
} else {
   $DLdir = $DLdir . "/" . $year ;	# this forces combined dataless into a yearly directory
   $VNDdir = $VNDdir . "/" . $year ;	# this forces VND into a yearly directory
}

#
# override defaults from pf file with command line choices
# No year or station based directories will be used
#

if ($opt_d) { 
    $VNDdir	=  $opt_d ; 
    $DLdir	=  $opt_d ; 
    $STADLdir	=  $opt_d ; 
    if ($opt_C) {
	elog_complain("Cannot use -C with -d.  Ignoring product directory $opt_C.\n");
    }
}

if ( $opt_V ) {
   $dir = $VNDdir ;
   if ($opt_C) {
        $fulldir = cleanpath($opt_C, nolinks) . "/" . $dir ;
   } else {
	$fulldir = $dir ;
   }
}

if ( $opt_D ) {
   $dir = $DLdir ;
   $dir = $STADLdir if $opt_s;
   if ($opt_C) {
	$fulldir = cleanpath($opt_C) . "/" . $dir ;
   } else {
	$fulldir = $dir ;
   }
}

if (! -d $fulldir ) {
    mkpath "$fulldir" ;
}

if ($opt_N) {
   $net = $opt_N ;
} elsif (pfget(site,default_seed_network)) {
   $net = pfget(site,default_seed_network) ;
} else {
   $net = "XX" ;
}

if ($opt_f) {
   $filename = $opt_f ;
} else {
   if ($opt_D) {
     if ($opt_s) {
        $filename = "DATALESS." . $net . "_" . $sta . "." . $year . "." . $month . "." . $day  ;
     } else { 
        $filename = "DATALESS." . $net . "." . $year . "." . $month . "." . $day  ;
     }
   } elsif ($opt_V) {
 	$filename = $vnet . "_" . $year. $month . $day . ".csv";
   }
} 

# check to see if filename name already exists.  If so, increment the filename
#  using -1, -2, -3, etc.

while (-e "$fulldir/$filename" || -e "$fulldir/$filename.gz") {
    elog_notify(0, "Filename, $filename, already exists.  Incrementing filename.\n") if ($opt_v);
    if (index($filename,"-") < 0) {
        $filename = $filename . "-1";
	elog_notify(0, "Attempting to change filename to: $filename \n") if ($opt_v);
    } elsif (index($filename,"-") >= 1) {
	$prefix = substr($filename,0,rindex($filename,"-")); 
	$suffix = substr($filename,rindex($filename,"-")+1);
	if ($suffix =~ /^[0-9]+$/) { #purely an integer
	    $filename = $prefix . "-" . ++$suffix;  
	}  else {
	    $filename = $filename . "-1";
	}
	elog_notify(0, "Attempting to change filename to: $filename \n") if ($opt_v);
    }
}

# create output dataless or VND

if ($opt_D) {
   if ($opt_s) {
#      $mkdl	= "mk_dataless_seed -o $dir/$filename $opt_v -s $opt_s $dbin " ;
      $mkdl	= "mk_dataless_seed -o $fulldir/$filename $opt_v -s $opt_s $dbin " ;
   } else {
#      $mkdl	= "mk_dataless_seed -o $dir/$filename $opt_v $dbin " ;
      $mkdl	= "mk_dataless_seed -o $fulldir/$filename $opt_v $dbin " ;
   }

   elog_notify(0, "Starting mk_dataless_seed. \n") if ($opt_v);
   elog_notify(0, "Cmd is: $mkdl  \n") if ($opt_v);

   # mk_dataless_seed output sent to STDOUT and STDERR is not captured by elog

   &run($mkdl);

} else {
#   $mkvnd	= "deployment2vnd $dbin $dir/$filename" ;
   $mkvnd	= "deployment2vnd $dbin $fulldir/$filename" ;

   elog_notify(0, "Starting deployment2vnd. \n") if ($opt_v);
   elog_notify(0, "Cmd is: $mkvnd \n") if ($opt_v);
    
   &run($mkvnd) ;
}

# zip, or don't zip, dataless

if ($opt_z) {
#  $zip	= "gzip $dir/$filename";
  $zip	= "gzip $fulldir/$filename";
  &run($zip);
  $filename = $filename . ".gz";
} 

# send or don't send dataless via orbxfer2
#
# If a product directory is specified, temporariliy 
#  cd to that directory so the transfer has the proper path
#

if ($opt_o) {
  $orb = $opt_o ;
  $xfer = "orbxfer2 $opt_v $dir/$filename $orb";
  chdir $opt_C if ($opt_C) ;
  &run($xfer);
  chdir $mycwd if ($opt_C) ;

  $subject = "New dataless: $dir/$filename\n" if $opt_D;
  $subject = "New VND: $dir/$filename\n" if $opt_V;
  
  open TEMP, ">$mailtmp" or die "Can't open '$mailtmp', stopped";

  print TEMP "\nTransferred $dir/$filename to $orb\n" ; 
  print TEMP "\nReason for update: $comment \n"; 

  close TEMP;

  &sendmail($subject, $opt_m, $mailtmp) if $opt_m ;

} else {
  $orb = "-";
  $subject = "New dataless: $dir/$filename\n" if $opt_D;
  $subject = "New VND: $dir/$filename\n" if $opt_V;

  open TEMP, ">$mailtmp" or die "Can't open '$mailtmp', stopped";

  print TEMP "\nStored $dir/$filename locally" ; 
  print TEMP " under $opt_C\n " if $opt_C ; 
  print TEMP "\n\nReason for update: $comment \n"; 

  close TEMP;

  &sendmail($subject, $opt_m, $mailtmp) if $opt_m ;
}

# open up tracking db

@db		= dbopen($dbtrack, "r+");
@dmcfiles	= dblookup(@db, "", "dmcfiles", "", "");

@dmcfiles_record = () ;
$auth        = "mdf:".getpwuid($<) ;

push(@dmcfiles_record,	"time", $now,
			"comment", $comment,
			"dir", abspath($fulldir),
			"dfile", $filename,
			"orb", $orb,
			"auth", $auth,
			) ;

# lddate is placed automatically via dbaddv

elog_notify(0, "Creating dmcfiles_record\n") if ($opt_v);
eval { dbaddv(@dmcfiles,@dmcfiles_record) };

if ($@) {
    warn $@;
    elog_notify(0, "Duplicate comment. Dfile: $dfile, Comment: $comment\n");
#    elog_complain(0, "Duplicate comment.  Will ignore.\n") if ($opt_v);
}


dbclose(@db);



exit(0);


sub get_pf {

  if ($opt_p) {
      $pf = $opt_p;
  } else {
      $pf = $pgm ;
  }

  $VNDdir		= pfget($pf, 'vnd_dir');
  $DLdir		= pfget($pf, 'dataless_dir');
  $STADLdir		= pfget($pf, 'sta_dataless_dir');

  if (!$comment) {	# only take default if comment is undef
      $comment	= pfget($pf, 'default_comment') ;
      chomp($comment);
  } 
}

sub run {               # run system cmds safely
    my ( $cmd ) = @_ ;
    system ( $cmd ) ;
    if ($?) {
        elog_complain(0, "$cmd error $? \n") ;
        exit(1); 
    }
}

sub cmdline {	# &cmdline();

    print STDERR "\ncommand line: \t $0" ;
    print STDERR " -v " if $opt_v  ;
    print STDERR " -z " if $opt_z  ;
    print STDERR " -p $opt_p" if $opt_p  ;
    print STDERR " -d $opt_d" if $opt_d  ;
    print STDERR " -C $opt_C" if $opt_C  ;
    print STDERR " -N $opt_N" if $opt_N  ;
    print STDERR " -s $opt_s" if $opt_s  ;
    print STDERR " -f $opt_f" if $opt_f  ;
    print STDERR " -m $opt_m" if $opt_m  ;
    print STDERR " -o $opt_o" if $opt_o  ;
    print STDERR " -D " if $opt_D  ;
    print STDERR " -V $opt_V" if $opt_V  ;
    if (@ARGV == 3) {
        printf STDERR " $ARGV[0] $ARGV[1] '$ARGV[2]'\n\n" ;
    } else {
        printf STDERR " $ARGV[0] $ARGV[1] \n\n" ;
    }

    return;
}
