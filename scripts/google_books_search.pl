#!/Users/brian/bin/perl5.14.1

use 5.010;

use Data::Dumper;
use JSON;
use LWP::Simple qw($ua getstore get);

$ENV{GOOGLE_BOOKS_KEY} = 'AIzaSyBmQKku5zKIOXMyjmBSpVox27HWdJUGg_E';

my $dir = "google_books.d";

mkdir "google_books.d" unless -d $dir;
chdir $dir;

$ua->default_header(
	'X-Forwarded-For' => '198.7.0.1'
	);

my $q = 'perl';

my $json = get( "https://www.googleapis.com/books/v1/volumes?q=$q&key=$ENV{GOOGLE_BOOKS_KEY}" );

$jsonner = JSON->new;
$hash = $jsonner->decode( $json );

my $max = $hash->{totalItems};
say "Found $max max items";

my $page_size = $ARGV[0] || 40;
my $iterations = $max / $page_size;

foreach $i ( 0 .. $iterations ) {
	my $start = $i * $page_size;
	say "Saving $start of $max";
	my $json = getstore( 
		"https://www.googleapis.com/books/v1/volumes?projection=full&maxResults=$page_size&startIndex=$start&q=$q&key=$ENV{GOOGLE_BOOKS_KEY}",
		"google-$q-$start.json"
		);
	}

