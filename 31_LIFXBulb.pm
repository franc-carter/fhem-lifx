
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
    $hash->{GetFn}    = "LIFXBulb_Get";
    $hash->{SetFn}    = "LIFXBulb_Set";
    $hash->{Match}    = ".*";
    $hash->{ParseFn}  = "LIFXBulb_Parse";
    $hash->{AttrList} = "IODev ".
 						"COLOR ".$readingFnAttributes;

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
		readingsBulkUpdate($bulb_hash, "HUE", $color->[0], 1);
		readingsBulkUpdate($bulb_hash, "SATURATION", $color->[1], 1);
		readingsBulkUpdate($bulb_hash, "BRIGHTNESS", $color->[2], 1);
		
		my $hsv = Imager::Color->new(
		    hsv     =>  [ ($color->[0]/65535*360), ($color->[2]/100), ($color->[1]/100) ]     #   hue, v, s
		);
		my @rgb = $hsv->rgba;
		readingsBulkUpdate($bulb_hash, "COLOR", sprintf("%02X%02X%02X", $rgb[0], $rgb[1], $rgb[2]), 1);
		readingsBulkUpdate($bulb_hash, "KELVIN", $color->[3], 1);
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

    if ($args[0] eq 'on') {
        $bulb->on();
        $hash->{STATE} = 'on';
    } elsif ($args[0] eq 'off') {
        $bulb->off();
        $hash->{STATE} = 'off';
    } elsif ($args[0] eq 'COLOR') {
        my ($color,$t) = @args[1 .. $#args];
		my $hsv = Imager::Color->new("#".$color);
		my ($h, $s, $b) = $hsv->hsv();
		print Dumper($h, $b, $s);
		
        $bulb->color([$h,$s*100,$b*100,0], $t);
    } elsif ($args[0] eq 'KELVIN') {
        my $color = $bulb->color();
        my $k     = $args[1];
        my $t     = $args[2] | 0;
        $bulb->color([0,0,$color->[2],$k], $t);
    } 	elsif ($args[0] eq 'BRIGHTNESS') {
	        my $color = $bulb->color();
	        my $t     = $args[2] | 1;
	
	        $bulb->color([$color->[0],$color->[1],$args[1],$color->[3]], $t);
	    } elsif ($args[0] eq 'rgb') {
        my ($r,$g,$b) = ($args[1] =~ m/(..)(..)(..)/);
        ($r,$g,$b)    = map {hex($_)} ($r,$g,$b);
        $bulb->rgb([$r,$g,$b], 0);
    }
    else {
        return "off:noArg on:noArg toggle:noArg COLOR:colorpicker,RGB BRIGHTNESS:slider,0,1,100 KELVIN:slider,2500,1,7000";
    }
    return undef;
}

sub LIFXBulb_Get($@)
{
	my ($hash, @a) = @_;

	  my $name = $a[0];
	  return "$name: get needs at least one parameter" if(@a < 2);

	  my $cmd= $a[1];
	if(!$LIFXBulb_gets{$cmd}) {
			my @cList = keys %LIFXBulb_gets;
			return "Unknown argument $cmd, choose one of " . join(" ", @cList);
		}
    
}

1;

