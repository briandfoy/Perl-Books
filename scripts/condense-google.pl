use strict;
use warnings;

use Data::Printer;
use JSON::XS;

package Local::JSON 0.01 {
	use Hash::AsObject;
	use JSON::XS;
	use Mojo::UserAgent;
	use File::Spec::Functions;

	my $user_agent = Mojo::UserAgent->new;

	sub volume_info {
		my( $self ) = @_;
		
		Hash::AsObject->new( $self->{items}[0]{volumeInfo} );
		}

	sub get_year {
		my( $self ) = @_;
	
		my $date = $self->volume_info->publishedDate;
		my( $year ) = $date =~ /\A(\d{4})(?:-\d\d?(?:-\d\d?)?)?\z/g;
		
		return $year;
		}
	
	sub get_title {
		my( $self ) = @_;
	
		my $title = $self->volume_info->title;
		$title .= ': ' . $self->volume_info->subtitle 
			if defined $self->volume_info->subtitle;
			
		return $title;
		}
		
	sub get_ids {
		my( $self ) = @_;
		
		my %ids;
		$ids{ 'Google Books' } =  $self->{items}[0]{id}; 
		
		foreach my $id ( @{ $self->volume_info->industryIdentifiers } ) {
			if( $id->{type} eq 'OTHER' and $id->{identifier} =~ /:/ ) {
				my( $type, $identifier ) = split /:/, $id->{identifier}, 2;
				$ids{ $type } = $identifier;
				next;		
				}
	
			$ids{ $id->{type} } = $id->{identifier};
			}
			
		return \%ids;
		}

	sub get_isbn {
		my( $self ) = @_;
	
		foreach my $hash ( @{ $self->volume_info->{industryIdentifiers} } ) {
			next unless $hash->{type} =~ /\AISBN_/;
			return $hash->{identifier};
			}

		return;
		}
	
	sub get_worldcat {
		my( $self ) = shift;
		
		my @related = ();
		my $isbn = $self->get_isbn;
		return {} unless defined $isbn;

		my $dir = catfile( qw( data xisbn ) );
		make_path( $dir, 0755 unless -d $dir );

		my $filename = catfile( $dir, "$isbn.json" );

		my $response = do {
			if( -e $filename ) {
				local $/;
				open my $fh, '<:encoding(UTF-8)', $filename or warn "Could not read $filename: $!";
				<$fh>;
				}
			else {
				my $response = $user_agent->get("http://xisbn.worldcat.org/webservices/xid/isbn/$isbn?method=getMetadata&fl=*&format=json")->res->body;
				open my $fh, '>:encoding(UTF-8)', $filename or warn "Could not write $filename: $!";
				print $fh $response;
				close $fh;
				$response;
				}
			};

		my $hash = decode_json( $response );
		
		return $hash;
		}

	}

my @books = ();
foreach my $file ( @ARGV ) {
	my $utf8_string = do {
		open my $fh, '<:raw', $file;
		local $/;
		<$fh>;
		};
		
	my $hash = decode_json( $utf8_string );
	my $obj = bless $hash, 'Local::JSON';

	next unless eval { exists $obj->{items}[0]{volumeInfo} };

	my( $year ) = $obj->get_year;
	next if( defined $year and $year < 1991 );
	
	my( $file_number ) = $file =~ /(\d+)/g;

	my $ids = $obj->get_ids;

	my $title = $obj->get_title;
	
	my $worldcat = $obj->get_worldcat;
	
	push @books, [$file_number, $year, $title, $ids, $worldcat ];
	}

no warnings 'uninitialized';
foreach my $book ( sort { $b->[1] <=> $a->[1] } @books ) {
	printf "%3d %4d %s\n", @$book;
	}
	
print "Found " . @books . " books\n";
p( @books );

sub get_year {
	my( $self ) = @_;

	my $date = $self->{items}[0]{volumeInfo}{publishedDate};
	my( $year ) = $date =~ /\A(\d{4})(?:-\d\d?(?:-\d\d?)?)?\z/g;
	
	return $year;
	}

sub get_title {
	my( $hash ) = @_;

	my $title = $hash->{items}[0]{volumeInfo}{title};
	$title .= ': ' . $hash->{items}[0]{volumeInfo}{subtitle} 
		if defined $hash->{items}[0]{volumeInfo}{subtitle};
		
	return $title;
	}
	
sub get_ids {
	my( $hash ) = @_;
	
	my @ids;
	push @ids, { 
		type       => 'Google Books', 
		identifier => $hash->{items}[0]{id} 
		};
	
	foreach my $id ( @{ $hash->{items}[0]{volumeInfo}{industryIdentifiers} } ) {
		if( $id->{type} eq 'OTHER' and $id->{identifier} =~ /:/ ) {
			my( $type, $identifier ) = split /:/, $id->{identifier}, 2;
			push @ids, { 
				type       => $type, 
				identifier => $identifier, 
				};
			next;		
			}

		push @ids, $id;
		}
		
	return \@ids;
	}

sub get_related_isbns {
	}
	
