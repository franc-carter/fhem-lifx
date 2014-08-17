
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

    if ($msg->type() == LIGHT_STATUS) {
        my $label           = $msg->label();
        my $bulb_hash       = $modules{LIFXBulb}{defptr}{$label};
        $bulb_hash->{STATE} = ($msg->power()) ? "on" : "off";

        DoTrigger($bulb_hash->{NAME}, $bulb_hash->{STATE});
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

    if ($args[0] eq 'on') {
        $bulb->on();
        $hash->{STATE} = 'on';
    } elsif ($args[0] eq 'off') {
        $bulb->off();
        $hash->{STATE} = 'off';
    } elsif ($args[0] eq 'color') {
        my ($b,$k,$h,$s,$t) = @args[1 .. $#args];
        $bulb->color([$h,$s,$b,$k], $t);
    } elsif ($args[0] eq 'rgb') {
        my ($r,$g,$b) = ($args[1] =~ m/(..)(..)(..)/);
        ($r,$g,$b)    = map {hex($_)} ($r,$g,$b);
        $bulb->rgb([$r,$g,$b], 0);
    }
    else {
        return "off:noArg on:noArg toggle:noArg rgb:colorpicker,RGB color:slider,2000,1,6500";
    }
    return undef;
}

1;

