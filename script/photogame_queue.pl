#!/usr/bin/perl

use strict;
use warnings;

use DBI;
use Imager;
use File::Spec;
use LWP::Simple;
use Digest::MD5 qw(md5_hex);

my $outputpath    = '/home/dean/git/PhotoGame/root/static';
my $thumbspath    = File::Spec->catfile( $outputpath, 'uploads', 'thumbs' );
my $originalspath = File::Spec->catfile( $outputpath, 'uploads', 'originals' );
my $previewspath  = File::Spec->catfile( $outputpath, 'uploads', 'previews' );
my $viewpath      = File::Spec->catfile( $outputpath, 'uploads', 'views' );
my $gravatarspath = File::Spec->catfile( $outputpath, 'gravatars' );

my $gravatarrating  = 'pg';
my $gravatarunknown = 'retro';

my $thumbsize   = 100;
my $previewsize = 400;
my $viewsize    = 1000;
my %fileoptions = ( type => 'jpeg', jpegquality => 90 );

my $dbname = 'photo_game';
my $dbuser = 'photo_game';
my $dbpass = 'ph0t0';

############# Nothing to change from here on down ##############

my $debug = $ARGV[0] || 0;
my %settings;

# check paths
for my $p ( $thumbspath, $originalspath ) {
    die "path doesnt exist $p\n" unless -d $p;
}

# connect to database
my $dbh = DBI->connect( "dbi:mysql:$dbname", $dbuser, $dbpass, {} )
  or die "Couldnt connect to database: $DBI::errstr";

sub delete_from_queue {

    my $id = shift or return;
    $debug && print "deleting $id from queue\n";
    return $dbh->do( q|DELETE FROM queue WHERE id = ?|, undef, $id )

}

sub add_to_specimens {

    my $file     = shift or return;
    my $filename = shift or return;
    my $md5      = shift or return;

    return $dbh->do(
q|INSERT INTO specimens (file_name, photographer_id, orig_name, orig_md5)
            VALUES (?,?,?,?) --|,
        undef,
        $filename,
        $file->{photographer_id},
        $file->{orig_name},
        $md5
    );

}

sub load_settings {

    my %s;
    my $sth = $dbh->prepare('SELECT * FROM settings');
    $sth->execute();
    while ( my $row = $sth->fetchrow_hashref() ) {
        $s{ $row->{key} } = $row->{value};
        $debug && print "\t", $row->{key}, ' : ', $row->{value}, "\n";
    }
    $sth->finish();
    return %s

}

sub check_md5_dupes {

    my $md5 = shift or return;
    my $sth =
      $dbh->prepare('SELECT count(*) FROM specimens WHERE orig_md5 = ?');
    $sth->execute($md5);
    my ($count) = $sth->fetchrow_array();
    $sth->finish();
    return if $count;
    return 1

}

sub check_no_specimens {

    my $file = shift or return;

    my $max = $settings{'max_submissions'}
      or return 1;    # if 0, then infinite

    my $sth =
      $dbh->prepare('SELECT count(*) FROM specimens WHERE photographer_id = ?');
    $sth->execute( $file->{photographer_id} );
    my ($count) = $sth->fetchrow_array();
    $sth->finish();
    return $max > $count

}

## main program ##

$debug && print "Loading settings...\n";
%settings = load_settings();

my $images = $dbh->selectall_arrayref( q|SELECT * FROM queue ORDER BY id --|,
    { Slice => {} } );

$debug && printf( "Found %d images in queue\n", scalar @$images );

my $count = 0;

# loop through files
FILESLOOP:
for my $file (@$images) {

    my $filename = +( File::Spec->splitpath( $file->{file_name} ) )[2];

    $debug && print "In filename is $filename\n";

    $filename =~ s/\.[A-z0-9]+$/.jpg/;

    $debug && print "Out filename will be $filename\n";

    # check there is space left for this entry, otherwise delete it
    unless ( check_no_specimens($file) ) {

        # delete queue entry and original file
        delete_from_queue( $file->{id} );

        $debug && printf(
            "Max submissions reached if %d, dropping %s\n",
            $file->{photographer_id},
            $file->{file_name}
        );

        next FILESLOOP;
    }

    # open original file
    my $image = Imager->new;
    unless ( $image->read( file => $file->{file_name} ) ) {

        delete_from_queue( $file->{id} );

        $debug
          && printf(
            q|Couldnt open %s because '%s', removing from queue| . "\n",
            $file->{file_name}, $image->errstr() );

        next FILESLOOP;
    }

    $debug && print "Read in file\n";

    my $md5 = do {
        open my $fh, '<', $file->{file_name}
          or $debug ? die "Failed to open file: $!" : next;
        Digest::MD5->new->addfile($fh)->hexdigest;
    };

    unless ( check_md5_dupes($md5) ) {

        # delete queue entry and original file
        delete_from_queue( $file->{id} );

        $debug
          && printf( "Duplicate md5 %s, dropping %s\n", $md5,
            $file->{file_name} );

        next FILESLOOP

    }

    $debug && print "md5 is $md5\n";

    # copy original to originals/
    my $originalfile = File::Spec->catfile( $originalspath, $filename );
    $image->write( file => $originalfile, %fileoptions )
      or $debug ? die $image->errstr : next;

    $debug && print "Copied original\n";

    # create a thumbnail in thumbs/
    my $thumb = $image->scale(
        xpixels => $thumbsize,
        ypixels => $thumbsize,
        type    => 'min'
    );
    my $thumbfile = File::Spec->catfile( $thumbspath, $filename );
    $thumb->write( file => $thumbfile, %fileoptions )
      or $debug ? die $thumb->errstr : next;

    $debug && print "Wrote out thumb\n";

    # create a preview in /preview
    my $preview = $image->scale(
        xpixels => $previewsize,
        ypixels => $previewsize,
        type    => 'min'
    );
    my $previewfile = File::Spec->catfile( $previewspath, $filename );
    $preview->write( file => $previewfile, %fileoptions )
      or $debug ? die $preview->errstr : next;

    $debug && print "Wrote out preview\n";

    # create a view at 1024x768ish to /
    my $view = $image->scale(
        xpixels => $viewsize,
        ypixels => $viewsize,
        type    => 'min'
    );
    my $viewfile = File::Spec->catfile( $viewpath, $filename );
    $view->write( file => $viewfile, %fileoptions )
      or $debug ? die $view->errstr : next;

    $debug && print "Wrote out view\n";

    # add to specimens
    add_to_specimens( $file, $filename, $md5 );

    $debug && print "$filename Done!\n";

    # delete queue entry and original file
    delete_from_queue( $file->{id} );

    $count++;

}

$debug && print "Processed $count files\n";

$count = 0;

$debug && print "Checking all gravatars are present\n";

my $photographers =
  $dbh->selectall_arrayref( q|SELECT * FROM photographers --|,
    { Slice => {} } );

$debug && printf( "Found %d photographers\n", scalar @$photographers );

for my $photographer (@$photographers) {

    my $hex = md5_hex( lc $photographer->{email_addr} ) . '.jpg';
    my $gravatarfile = File::Spec->catfile( $gravatarspath, $hex );
    next if -e $gravatarfile;

    my $uri = sprintf( 'http://gravatar.com/avatar/%s?r=%s&d=%s',
        $hex, $gravatarrating, $gravatarunknown );

    $debug
      && printf( "For '%s' uri is %s\n", $photographer->{full_name}, $uri );

    my $gravatar = get($uri);
    next unless $gravatar;

    open( my $fh, '>', $gravatarfile )
      or next;
    print $fh $gravatar;
    close $fh;

    $dbh->do(
        q|UPDATE photographers SET avatar = ? WHERE photographer_id = ? --|,
        undef, $hex, $photographer->{photographer_id} );

    $debug && printf(
        "Completed processing '%s', wrote file %s\n",
        $photographer->{full_name},
        $gravatarfile
    );

    $count++;
}

$debug && print "Processed $count gravatars\n";

$dbh->disconnect();
