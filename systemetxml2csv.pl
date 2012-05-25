#!/usr/bin/perl -w
use strict; # Because you should
use XML::Simple; # Used to read the actual XML file
use Data::Dumper; # This isn't used in the script except for trouble shooting purposes, it allows you to view the array produced by the XML file in the same way perl does
use Number::Format; # This is used to round off decimal places
use POSIX; # For the localtime
use LWP::Simple; # For downloading the actual file from systembolaget.se
use IO::Handle; # 


# This script parses the systembolaget XML file and produces a CSV file, semi-colon deliminated
# Setup local time for downloads, logs, output files etc...
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);

# Gets the time, formated with full day name and everything, using the format of the DATE command for linux.
my $ct = strftime "%a %b %e %H:%M:%S %Y", localtime;
# Month and day, in digits, for filenames
my $filedate = strftime "%m%e", localtime;

# Add some logging
my $logfile = "systemet.log";
open LOGFILE, ">>$logfile";

# Get the file
my $dlurl = "http://www.systembolaget.se/Assortment.aspx?Format=Xml";
my $dlfile = "systemet$filedate.xml";
getstore($dlurl, $dlfile) or die $!;
# This just checks to see if the file is there or not, if it's not it probably wasn't downloaded correctly.
if (! -e $dlfile) {
		print LOGFILE "$ct: File not found, did it download correctly?\n"; die $!;
		}
	else {
		print LOGFILE "$ct: File downloaded successfully\n";
		}	
# Redirect STDOUT to a file, it's an ugly hack but I had encoding issues when writing to a file
open OUTPUT, '>', "systemet$filedate.csv" or die $!;
STDOUT->fdopen( \*OUTPUT, 'w' ) or die $!;


# What file to use?
my $file = $dlfile;
# Idencticle to the download check, but just thrown in incase something went wrong between then and now
if (! -e $file) {print LOGFILE "$ct: XML File Doesn't exist\n"; die;}
# Read in the data
my $data = XMLin($file);
my $num = new Number::Format;

# CSV Header
print 'namn;name2;country;price;varu;alcperc;type;type2;volume;alcpper;krplit;flagname'. "\n";

# The actual looping, complete with a lot of weird math, sanitation and a bunch of other stuff. It ends at the last } in the script.
	binmode(STDOUT, ":utf8");
	foreach my $status (@{$data->{artikel}}) {
		print $status->{Namn} . ';';
	# If statement to weed out empty references
	if (ref($status->{Namn2}) eq ref({})
	&& !keys %{ $status->{Namn2} }){
			print ';';
				}
			else {
				print $status->{Namn2} . ';';
				}

		# Prints all the values in a semi-colon seperated fasion
		print $status->{Ursprunglandnamn} . ';';

		# Remo the last two digits from price (it was followed by 4 digits after the decimal)
		$status->{Prisinklmoms} =~ s/\d{2}$//;
		print $status->{Prisinklmoms} . ';';

		# Remove the last two digits from the varunum, for some reason they threw two on needlessly.
		$status->{nr} =~ s/\d{2}$//;
		print $status->{nr} . ';';

		# Change the comma to a period in the alcohol percent
		$status->{Alkoholhalt} =~ s/\,/./;

		# Remove the percentage...seems like a useless symbol to me
		$status->{Alkoholhalt} =~ s/\%//;
		print $status->{Alkoholhalt} . ';';

		# Get the aclohol type (öl, vinn etc...) and seperate them at the comma så you get another value for ale, mörk lager and what not
		my $low = "\L$status->{Varugrupp}";
		$low =~ s/([\w']+)/\u\L$1/g;
		if ($low =~ m/,/) 
			{
				my @type = split(/,/, $low); # The actual split
				foreach (@type) {
       				$_ =~ s/^\s+//; # Remove any leading white space
       				print $_ . ";"; # Do the actual printing
			}}
			else
			{
                                print "$low;;";
                        }		
		
		#print $low . ';';  

		# Remove the shitload of digits after the decimal
		$status->{Volymiml} =~ s/\.\d{2,4}//; 
		print $status->{Volymiml} . ';';

		# Set the array values as variable for a few things to make the math easier to deal with (for me)
		my $vol = $status->{Volymiml};
		my $cost = $status->{Prisinklmoms};
		my $alcper = $status->{Alkoholhalt};

		# Gets the kroner per litre, which isn't included in the XML file
		my $volfix = 1000 / $vol;
		my $krplit = $volfix * $cost;
		my $krplitfixed = $num->round($krplit) . ';';

		# Time for math!
		# If statement filters out zeros, as computers don't really like them when dividing
		if ($status->{Alkoholhalt} eq 0)
			{
				print '0;';
			}
			else {
				# Now the math to get Alcohol Per Kroner
				# Now we divide the kroner per liter by the total alcohol percentage 
				my $krpper = $krplit / $alcper;
				my $krpperfix = $num->round($krpper);
				print "$krpperfix" . ';';
			}
		
		print $krplitfixed;

		# This last function is to create a sanitized version of the country name to use for image association (no öåä and no spaces)
		my $flagname = $status->{Ursprunglandnamn};

		# change ä and å in a (hex is needed here)
		$flagname =~ s/[\xe4\xe5]/a/g;

		# now for Å and Ä
		$flagname =~ s/[\xc4\xc5]/A/g;

		# Remove spaces
		$flagname =~ s/ //g;

		# Replace ö with o (and then Ö with O)
		$flagname =~ s/\xd6/O/g;
		$flagname =~ s/\xf6/o/g;
		# And now we print the flag name!
		print "$flagname\n" ;
} # End of the loop
print LOGFILE "$ct: Seems like everyting went fine!\n";
close LOGFILE;
