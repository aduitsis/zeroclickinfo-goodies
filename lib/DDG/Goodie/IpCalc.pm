package DDG::Goodie::IpCalc;

use 5.14.0;
use strict;
use warnings;
use Moo;
use Data::Printer;
use DDG::Block::Blockable::Triggers;
use utf8::all;

# doing use DDG::Goodie does:
# use Moo;
# use Data::Printer;
# use utf8::all;
# installs a zci_new method (returns a DDG::ZeroClickInfo object)
# installs a zci method ( setter for parameters of ZeroClickInfo objects)
# installs triggers_block_type, get_triggers, has_triggers, triggers methods, initializes an empty $triggers var
# applies the DDG::Block::Blockable role to this package. Role has a readonly 'block' attribute
# also, role DDG::Block::Blockable requires the existence of a get_triggers method
# installs a handle method 
#use DDG::Goodie;

# this is the predicate that will activate the plugin . 
#triggers start => 'chars'; 

my $re = qr/(\d+)\.(\d+)\.(\d+)\.(\d+)\/(\d+)/;

# create a new triggers object
my $triggers = DDG::Block::Blockable::Triggers->new;
# also see https://github.com/duckduckgo/duckduckgo/blob/master/lib/DDG/Block/Blockable/Triggers.pm 
$triggers->add( query => $re );

sub triggers_block_type {
	return $triggers->block_type;
}
sub get_triggers {
	return $triggers->get;
}
sub has_triggers {
	 $triggers ? 1 : 0;
}

#handle remainder => sub {
#    return length $_ if $_;
#    return;
#};
#it is also permissible to say handle( sub { ... } ) in which case it is
#assumed that 'query_raw' type is used

sub handle_request_matches {
	my ( $self, $request, @parts ) = @_;
	say p(@_);	

	my @ret_str;
	eval {
		my $ip = IPv4Subnet->new( join('.',@parts[0..3]).'/'.$parts[4] );
		@ret_str = ( 'start:'.$ip->get_start_ip.' stop:'.$ip->get_stop_ip , 'mask:'.$ip->get_mask.' wildcard:'.$ip->get_wildcard, 'net:'.$ip->get_start_ip.'/'.$ip->get_length_n.' length:'.$ip->get_length);
	};
	if(!$@) {
		return DDG::ZeroClickInfo->new( answer_type => 'IpCalc' , answer => \@ret_str , is_cached => 1 );
		
	} 
	else {
		print STDERR $@;
		return;
	}
}	


#this makes all future invokations of zci_new include an is_cached=>1 pair. 
#note also, for a module named DDG::Goodie::Foo::Bar, zci_new will 
#automatically include an answer_type=>'Foo Bar' pair. 
#zci is_cached => 1;


# the IPv4Subnet package original source can be found at:
# https://github.com/aduitsis/IPv6Address
# included here to make the IpCalc goodie self-contained

package IPv4Subnet;

use Socket;
use strict;
use Carp;
use warnings;
use Data::Dumper;

my $DEBUG;

sub new {
	defined ( my $class = shift ) or die "missing class";
	defined ( my $str = shift ) or die "missing string";
	my ( $ip , $length_n ) = ( $str =~ /^(\d+\.\d+\.\d+\.\d+)\/(\d+)$/ ) or croak 'Cannot parse $str';
	bless { ip_n => my_aton($ip) , length_n => $length_n } , $class	;
}

sub get_ip_n {
	return $_[0]->{ip_n} ;
}

sub get_start {
	return $_[0]->get_ip_n & $_[0]->get_mask_n;
}

sub get_stop {
	return $_[0]->get_start + $_[0]->get_length - 1;
}

sub get_start_ip {
	return my_ntoa($_[0]->get_start);
}

sub get_stop_ip {
	return my_ntoa($_[0]->get_stop);
}

sub get_length {
	return 2**(32-$_[0]->get_length_n);
}

sub get_length_n {
	return $_[0]->{length_n};
}

sub get_mask_n {
	($_[0]->get_length_n == 0 )?
		0 : hex('0xffffffff') << ( 32 - $_[0]->get_length_n )  ;
}	

sub get_mask {
	my_ntoa( $_[0]->get_mask_n );
}

sub get_wildcard {
	my_ntoa( ~ $_[0]->get_mask_n );
}

sub my_aton {
	defined ( my $aton_str = inet_aton( $_[0] ) ) or croak '$_[0] cannot be fed to inet_aton';
	return unpack('N',$aton_str);
}

sub my_ntoa {
	return inet_ntoa(pack('N',$_[0]));
}

sub position { 
	my $self = shift;
	defined ( my  $arg = shift ) or die "Incorrect call";
	my $number = my_aton($arg);
	$DEBUG && print STDERR "number is ",my_ntoa($number)," and start is ",my_ntoa($self->get_start)," and stop is ",my_ntoa($self->get_stop),"\n";
	return $number - $self->get_start;
}

sub contains {
	return ( ($_[0]->position($_[1]) < $_[0]->get_length) && ( $_[0]->position($_[1]) >= 0 ) )? 1 : 0;
}

sub calculate_compound_offset {
	defined( my $address = shift ) or die 'missing address';
	defined( my $blocks = shift ) or die 'missing block reference';
	
	my $offset = 0;
	for my $block (@{$blocks}) {
		my $subnet = IPv4Subnet->new($block);
		if ($subnet->contains($address)) {
			return ( $subnet->position($address) + $offset );
		}
		else {
			$offset = $offset + $subnet->get_length;
		}
	}
	die "Address $address does not belong to range:",join(',',@{$blocks});
	return;
}

=head1 COPYRIGHT & LICENSE 
 
Copyright 2012 Athanasios Douitsis, all rights reserved.
 
This program is free software; you can use it
under the terms of Artistic License 2.0 which can be found at 
http://www.perlfoundation.org/artistic_license_2_0
 
=cut


1;
		
	
