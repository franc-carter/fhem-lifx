package main;

use strict;
use warnings;
use POSIX;
use Device::LIFX;
use Device::LIFX::Constants qw(LIGHT_STATUS);
use SetExtensions;
use Color;
use Data::Dumper;
use Imager::Color;

my %LIFXBulb_gets = (
	"status"	=> "Z"
);

sub LIFXBulb_Initialize($)
{
    my ($hash) = @_;

    $hash->{DefFn}    = "LIFXBulb_Define";
    $hash->{SetFn}    = "LIFXBulb_Set";
    $hash->{Match}    = ".*";
    $hash->{ParseFn}  = "LIFXBulb_Parse";
    $hash->{AttrList} = "IODev ".
 						"color ".$readingFnAttributes;

    FHEM_colorpickerInit();
}

sub LIFXBulb_Parse($$)
{
    my ($hash, $msg) = @_;

    if ($msg->type() == LIGHT_STATUS) {
        my $label = $msg->label();
        my $bulb_hash = $modules{LIFXBulb}{defptr}{$label};
        if (!defined($bulb_hash)) {
            my $mac    = $msg->bulb_mac();
            $bulb_hash = $modules{LIFXBulb}{defptr}{$mac};
        }
        $bulb_hash->{STATE} = ($msg->power()) ? "on" : "off";
		my $color = $msg->color();
	
        readingsBeginUpdate($bulb_hash);
		readingsBulkUpdate($bulb_hash, "hue", $color->[0], 1);
		readingsBulkUpdate($bulb_hash, "saturation", $color->[1], 1);
		readingsBulkUpdate($bulb_hash, "brightness", $color->[2], 1);
		my $hue = $color->[0]/65535*360;
		my $saturation = $color->[1]/100;
		my $brightness = $color->[2]/100;
		my $hsv = Imager::Color->new(
		    hsv=>[$hue, $saturation, $brightness]    
		);
		my @rgb = $hsv->rgba;
		readingsBulkUpdate($bulb_hash, "red", sprintf("%d", $rgb[0]), 1);
		readingsBulkUpdate($bulb_hash, "green", sprintf("%d", $rgb[1]), 1);
		readingsBulkUpdate($bulb_hash, "blue", sprintf("%d", $rgb[2]), 1);
		
		readingsBulkUpdate($bulb_hash, "color", sprintf("%02X%02X%02X", $rgb[0], $rgb[1], $rgb[2]), 1);
		readingsBulkUpdate($bulb_hash, "kelvin", $color->[3], 1);
        readingsEndUpdate($bulb_hash,1);

        DoTrigger($bulb_hash->{NAME}, $bulb_hash->{STATE}, $bulb_hash->{READINGS});
    }
    return undef;
}

sub LIFXBulb_Define($$)
{
    my ($hash, $def) = @_;

    my ($name, $type, $id) = split(' ', $def);
    if (!defined($id)) {
        return "Usage: <NAME> LIFXBulb <XX:XX:XX:XX:XX:XX>|Label"
    }

    my @mac = split(':',$id);
    if ($#mac == 5) {
        @mac = map {hex($_)} @mac;
        $id = pack('C*', @mac);
    }

    $hash->{STATE} = 'Initialized';
    $hash->{ID}    = $id;
    $hash->{NAME}  = $name;

    AssignIoPort($hash);
    if(defined($hash->{IODev}->{NAME})) {
        Log3 $name, 1, "$name: I/O device is " . $hash->{IODev}->{NAME};
    } else {
        Log3 $name, 1, "$name: no I/O device";
    }

    $modules{LIFXBulb}{defptr}{$id} = $hash;

    return undef;
}

sub LIFXBulb_Undefine($$)
{
  my ($hash,$arg) = @_;

  RemoveInternalTimer($hash);

  return undef;
}

sub LIFXBulb_Set($@)
{
    my ($hash,$name,@args) = @_;

    my $lifx = $hash->{IODev}->{lifx}{lifx};
    my $id   = $hash->{ID};
    my $bulb = $lifx->get_bulb_by_label($id);
    if (!defined($bulb)) {
        $bulb = $lifx->get_bulb_by_mac($id);
    }
	if (!defined($bulb)) {
		return undef;
	}

    if ($args[0] eq 'on') {
        $bulb->on();
        $hash->{STATE} = 'on';
    } elsif ($args[0] eq 'off') {
        $bulb->off();
        $hash->{STATE} = 'off';
    } elsif ($args[0] eq 'color') {
        my ($color,$t) = @args[1 .. $#args];
		my $hsv = Imager::Color->new("#".$color);
		my ($h, $s, $b) = $hsv->hsv();
		print Dumper($h/360*65535, $b*100, $s*100);
		
        $bulb->color([sprintf("%d", $h/360*65535),sprintf("%d", $s*100), sprintf( "%d", $b*100),0], $t);
    } elsif ($args[0] eq 'kelvin') {
        my $color = $bulb->color();
        my $k     = $args[1];
        my $t     = $args[2] | 0;
        $bulb->color([0,0,$color->[2],$k], $t);
    } 	elsif ($args[0] eq 'brightness') {
	        my $color = $bulb->color();
	        my $t     = $args[2] | 1;
	
	        $bulb->color([$color->[0],$color->[1],$args[1],$color->[3]], $t);
	    } elsif ($args[0] eq 'rgb') {
        my ($r,$g,$b) = ($args[1] =~ m/(..)(..)(..)/);
        ($r,$g,$b)    = map {hex($_)} ($r,$g,$b);
        $bulb->rgb([$r,$g,$b], 0);
    }
    else {
        return "off:noArg on:noArg toggle:noArg color:colorpicker,RGB brightness:slider,0,1,100 kelvin:slider,2500,1,7000";
    }
    return undef;
}

1;
