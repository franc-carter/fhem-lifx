
package main;

use strict;
use warnings;
use POSIX;

use vars qw($FW_ME);      # webname (default is fhem), needed by Color
use Color;
use JSON::PP;
use HTTP::Request;
use LWP::UserAgent;
use SetExtensions;
use Device::LIFX;
use Data::Dumper;

sub LIFXBridge_Initialize($$)
{
    my ($hash) = @_;

    # Provider
    $hash->{ReadFn}   = "LIFXBridge_Read";
    $hash->{Clients}  = ":LIFXBulb:";

    #Consumer
    $hash->{DefFn}    = "LIFXBridge_Define";
    $hash->{AttrList} = "key";
}

sub LIFXBridge_Define($$)
{
    my ($hash, $def) = @_;

    my ($name, $type, $interval) = split("[ \t]+", $def);
    if (!defined($type)) {
       return "Usage: define <name> LIFXBridge [gateway search interval]";
    }

    $hash->{ID}         = "LIFXBridge";
    $hash->{NAME}       = $name;
    $hash->{INTERVAL}   = $interval || 60;
    $hash->{STATE}      = 'Initialized';
    $hash->{lifx}{lifx} = Device::LIFX->new();;
    $hash->{FD}         = fileno($hash->{lifx}{lifx}->socket());
    $selectlist{$name}  = $hash;

    InternalTimer(gettimeofday()+$hash->{INTERVAL}, "LIFXBridge_GetUpdate", $hash, 0);

    return undef;
}

sub LIFXBridge_GetUpdate($)
{
    my ($hash) = @_;

    $hash->{lifx}{lifx}->find_gateways();

    InternalTimer(gettimeofday()+$hash->{INTERVAL}, "LIFXBridge_GetUpdate", $hash, 0);
}

sub LIFXBridge_Read($)
{
    my ($hash) = $_[0];

    my $lifx = $hash->{lifx}{lifx};
    my $msg  = $lifx->get_message();

    Dispatch($hash, $msg, undef);

    return undef;
}

1;

