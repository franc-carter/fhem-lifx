
package main;

use strict;
use warnings;
use POSIX;
use Device::LIFX;
use Device::LIFX::Constants qw(LIGHT_STATUS);
use SetExtensions;
use Color;
use Data::Dumper;

sub LIFXBulb_Initialize($)
{
    my ($hash) = @_;

    $hash->{DefFn}    = "LIFXBulb_Define";
    $hash->{SetFn}    = "LIFXBulb_Set";
    $hash->{Match}    = ".*";
    $hash->{ParseFn}  = "LIFXBulb_Parse";
    $hash->{AttrList} = "IODev ". $readingFnAttributes;

    FHEM_colorpickerInit();
}

sub LIFXBulb_Parse($$)
{
    my ($hash, $msg) = @_;

    my $label = $msg->label();
    my $bulb_hash = $modules{LIFXBulb}{defptr}{$label};
    if (!defined($bulb_hash)) {
        my $mac    = $msg->bulb_mac();
        $bulb_hash = $modules{LIFXBulb}{defptr}{$mac};
    }
    if ($msg->type() == LIGHT_STATUS) {
        $bulb_hash->{STATE} = ($msg->power()) ? "on" : "off";

        DoTrigger($bulb_hash->{NAME}, $bulb_hash->{STATE});
    }
    return $bulb_hash->{NAME} || $hash->{NAME};
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
        defined($bulb) ||
            return "Can't find bulb with id: $id";
    }

    if ($args[0] eq 'on') {
        $bulb->on();
        $hash->{STATE} = 'on';
    } elsif ($args[0] eq 'off') {
        $bulb->off();
        $hash->{STATE} = 'off';
    } elsif ($args[0] eq 'color') {
        my ($b,$k,$h,$s,$t) = @args[1 .. $#args];
        $bulb->color([$h,$s,$b,$k], $t);
    } elsif ($args[0] eq 'kelvin') {
        my $color = $bulb->color();
        my $k     = $args[1];
        my $t     = $args[2] | 0;
        $bulb->color([0,0,$color->[2],$k], $t);
    } elsif ($args[0] eq 'rgb') {
        my ($r,$g,$b) = ($args[1] =~ m/(..)(..)(..)/);
        ($r,$g,$b)    = map {hex($_)} ($r,$g,$b);
        $bulb->rgb([$r,$g,$b], 0);
    }
    else {
        return "off:noArg on:noArg toggle:noArg rgb:colorpicker,RGB kelvin:slider,2500,1,7000";
    }
    return undef;
}

1;

