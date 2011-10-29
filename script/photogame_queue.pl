#!/usr/bin/perl

use strict;
use warnings;

use DBI;
use Imager;
use File::Spec;
use LWP::Simple;
use Digest::MD5 qw(md5_hex);

my $outputpath    = '/home/dean/git/PhotoGame/root/static';
my $thumbspath    = File::Spec->catfile($outputpath, 'uploads', 'thumbs');
my $originalspath = File::Spec->catfile($outputpath, 'uploads', 'originals');
my $previewspath  = File::Spec->catfile($outputpath, 'uploads', 'previews');
my $gravatarspath = File::Spec->catfile($outputpath, 'gravatars');

my $gravatarrating  = 'pg';
my $gravatarunknown = 'retro';

my $thumbsize   = 100;
my $previewsize = 400;
my $viewsize    = 1000;

my $dbname = 'photo_game';
my $dbuser = 'photo_game';
my $dbpass = 'ph0t0';

############# Nothing to change from here on down ##############

my $debug = $ARGV[0] || 0;

# check paths
for my $p ($thumbspath, $originalspath) {
    die "path doesnt exist $p\n" unless -d $p
}

# connect to database
my $dbh = DBI->connect("dbi:mysql:$dbname",$dbuser, $dbpass, {} )
    or die "Couldnt connect to database: $DBI::errstr";

sub delete_from_queue {

    my $id = shift or return;
    $debug && print "deleting $id from queue\n";
    return $dbh->do(q|DELETE FROM queue WHERE id = ?|,undef,$id)

}

sub add_to_specimens {

    my $file = shift or return;

    return $dbh->do(
    q|INSERT INTO specimens (file_name, photographer_id, orig_name) VALUES (?,?,?) --|,
    undef,
    +(File::Spec->splitpath($file->{file_name}))[2],
    $file->{photographer_id},
    $file->{orig_name}
    );

}

## main program ##

my $images = $dbh->selectall_arrayref(
    q|SELECT * FROM queue ORDER BY id --|,{ Slice => {} });

$debug && printf('Found %d images in queue', scalar @$images);

my $count = 0;

# loop through files
FILESLOOP:
for my $file (@$images) {

    my $filename = +(File::Spec->splitpath($file->{file_name}))[2];

    $debug && print "Filename is $filename\n";

    # open original file
    my $image = Imager->new;
    unless ($image->read( file => $file->{file_name} )) {

        delete_from_queue($file->{id});

        $debug && printf(q|Couldnt open %s because '%s', removing from queue|."\n",
            $file->{file_name},$image->errstr());

        next FILESLOOP
    }

    $debug && print "Read in file\n";

    # copy original to originals/
    my $originalfile = File::Spec->catfile($originalspath,$filename);
    $image->write( file => $originalfile )
        or next; # FIXME ?

    $debug && print "Copied original\n";

    # create a thumbnail in thumbs/
    my $thumb = $image->scale(xpixels => $thumbsize,
                            ypixels => $thumbsize,
                            type => 'min');
    my $thumbfile = File::Spec->catfile($thumbspath,$filename);
    $thumb->write( file => $thumbfile )
        or next; # FIXME ?

    $debug && print "Wrote out thumb\n";

    # create a preview in /preview
    my $preview = $image->scale(xpixels => $previewsize,
                                ypixels => $previewsize,
                                type => 'min');
    my $previewfile = File::Spec->catfile($previewspath,$filename);
    $preview->write( file => $previewfile )
        or next; # FIXME ?

    $debug && print "Wrote out preview\n";

    # create a view at 1024x768ish to /
    my $view = $image->scale(xpixels => $viewsize,
                                ypixels => $viewsize,
                                type => 'min');
    my $viewfile = File::Spec->catfile($outputpath,$filename);
    $view->write( file => $viewfile )
        or next; # FIXME ?

    $debug && print "Wrote out view\n";

    # add to specimens
    add_to_specimens($file);

    $debug && print "$filename Done!\n";

    # delete queue entry and original file
    delete_from_queue($file->{id});

    $count++;

}

$debug && print "Processed $count files\n";

$count = 0;

$debug && print "Checking all gravatars are present\n";

my $photographers = $dbh->selectall_arrayref(
    q|SELECT * FROM photographers --|,{ Slice => {} });

$debug && printf("Found %d photographers\n", scalar @$photographers);

for my $photographer (@$photographers) {

    my $hex = md5_hex(lc $photographer->{email_addr}) . '.jpg';
    my $gravatarfile = File::Spec->catfile($gravatarspath,$hex);
    next if -e $gravatarfile;

    my $uri = sprintf('http://gravatar.com/avatar/%s?r=%s&d=%s',
                          $hex,$gravatarrating,$gravatarunknown);

    $debug && printf("For '%s' uri is %s\n",$photographer->{full_name},$uri);

    my $gravatar = get($uri);
    next unless $gravatar;

    open( my $fh, '>', $gravatarfile )
        or next;
    print $fh $gravatar;
    close $fh;

    $dbh->do(
        q|UPDATE photographers SET avatar = ? WHERE photographer_id = ? --|,
        undef,$hex, $photographer->{photographer_id}
    );

    $debug && printf("Completed processing '%s', wrote file %s\n",
                  $photographer->{full_name},$gravatarfile);

    $count++;
}

$debug && print "Processed $count gravatars\n";

$dbh->disconnect();
