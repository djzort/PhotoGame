#!/usr/bin/perl

use strict;
use warnings;

use DBI;
use Imager;
use File::Spec;

my $outputpath = '/home/dean/git/PhotoGame/root/static/uploads';
my $thumbspath = File::Spec->catfile($outputpath, 'thumbs');
my $originalspath = File::Spec->catfile($outputpath, 'originals');

my $thumbsize = 400;
my $viewsize = 1000;

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
    return $dbh->do(q|DELETE FROM queue WHERE id = ?|,undef,$id)

}

sub add_to_specimens {

    my $file = shift or return;

    return $dbh->do(
    q|INSERT INTO specimens (file_name, photographer_id, orig_name) VALUES (?,?,?)|,
    undef,
    +(File::Spec->splitpath($file->{file_name}))[2],
    $file->{photographer_id},
    $file->{orig_name}
    );

}

my $images = $dbh->selectall_arrayref(
    q|SELECT * FROM queue ORDER BY id|,{ Slice => {} });

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

    # create a thumbnail at 200x200ish to thumbs/
    my $thumb = $image->scale(xpixels => $thumbsize,
                            ypixels => $thumbsize,
                            type => 'min');
    my $thumbfile = File::Spec->catfile($thumbspath,$filename);
    $thumb->write( file => $thumbfile )
        or next; # FIXME ?

    $debug && print "Wrote out thumb\n";

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

$dbh->disconnect();
