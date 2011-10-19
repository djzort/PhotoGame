package PhotoGame::Model::DB;

use strict;
use warnings;
use parent 'Catalyst::Model::DBI';
use List::Util qw(first shuffle);

__PACKAGE__->config( );

=head1 NAME

PhotoGame::Model::DB - DBI Model Class

=head1 SYNOPSIS

See L<PhotoGame>

=head1 DESCRIPTION

DBI Model Class.

=head1 METHODS

=head2 add_queue

Adds a specimen to the queue for processing

=cut

sub add_queue {

    my $self = shift;

    my ( $orig_name, $file_name, $photographer_id ) = @_;

    my $return = $self->dbh->do(q|INSERT INTO queue (orig_name, file_name, photographer_id) VALUES (?,?,?) --|,
        undef, $orig_name, $file_name, $photographer_id )
        or die $self->dbh->errstr;

    return $return

}

=head2 check_user {

=cut

sub check_user {

    my $self = shift;
    my $user = shift or return;
    my $pass = shift or return;

    my $sth = $self->dbh->prepare_cached(
    q|SELECT photographer_id, full_name, email_addr FROM photographers
        WHERE username = ? AND password = SHA1(?)
        LIMIT 1 --|
        );

    my $results = $self->dbh->selectall_arrayref( # no reason to unpack dbh since we use it once
        $sth,
        { Slice => {} },    # this results in an array of hashrefs
        ( $user, $pass ) # bind values, yes arrays in arrays is pointless, but braces for emphasis
    )
    or die $self->dbh->errstr;

    return shift @$results

}

=head2 create_photographer

Creates a new photographer

=cut

sub create_photographer {

    my $self = shift;

    my %args = @_;

    my $sth = $self->dbh->prepare_cached(
                q|INSERT INTO photographers
                (full_name, email_addr, username, password, creation_ip)
                VALUES (?,?,?,SHA1(?),?) --|);


    my $return = $sth->execute(@args{qw( full_name email_addr username password creation_ip )})
        or die $self->dbh->errstr;

    return $return

}

=head2 get_all_specimens

Returns a list or arrayref containing hashrefs, each describing one of
the submitted and processed specimens, including the photographers
details

=cut

sub get_all_specimens {

    my $self = shift;

    my $sth = $self->dbh->prepare_cached(
        q|SELECT `specimens`.`photographer_id`,
                `full_name`,
                `email_addr`,
                `file_name`,
                `orig_name`
            FROM `specimens`
            INNER JOIN `photographers`
            ON `specimens`.`photographer_id` =
                `photographers`.`photographer_id`
                --|
    );

    my $results = $self->dbh->selectall_arrayref(
        $sth,
        { Slice => {} },    # this results in an array of hashrefs
    )
    or die $self->dbh->errstr;

    return unless ref $results;
    return wantarray ? @$results : $results

}

=head2 get_my_queue($id)

Returns a list or arrayref containing hashrefs, each describing one of
my queued photo specimen submissions

These results arent relevant for very long

=cut

sub get_my_queue {

    my $self = shift;
    my $id = shift or return;

    my $sth = $self->dbh->prepare_cached(
        q|SELECT * FROM `queue` WHERE `photographer_id` = ? --|
    );

    my $results = $self->dbh->selectall_arrayref(
        $sth,
        { Slice => {} },    # this results in an array of hashrefs
        ( $id ) # bind values, yes arrays in arrays is pointless, but braces for emphasis
    )
    or die $self->dbh->errstr;

    return unless ref $results;
    return wantarray ? @$results : $results

}

=head2 get_my_specimen($id)

Returns a list or arrayref containing hashrefs, each describing one of
my photo specimen submissions

=cut

sub get_my_specimen {

    my $self = shift;
    my $id = shift or return;

    my $sth = $self->dbh->prepare_cached(
        q|SELECT * FROM `specimens` WHERE `photographer_id` = ? --|
    );

    my $results = $self->dbh->selectall_arrayref(
        $sth,
        { Slice => {} },    # this results in an array of hashrefs
        ( $id ) # bind values, yes arrays in arrays is pointless, but braces for emphasis
    )
    or die $self->dbh->errstr;

    return unless ref $results;
    return wantarray ? @$results : $results

}

=head2 get_setting($setting)

Returns the value of the I<$setting>

=cut

sub get_setting {

    my $self = shift;
    my $key = shift or return;

    my $sth = $self->dbh->prepare_cached(
        q|SELECT `value` FROM `settings` WHERE `key` = ? LIMIT 1 --|
    );

    my @results = $self->dbh->selectrow_array(
        $sth, undef, ( $key )
    );

    return unless @results;
    return $results[0]

}

=head2 get_two_random_specimens($ip)

Retrieves two random specimens (that have not been voted for by $ip)

=cut

sub get_two_random_specimens {

    my $self = shift;
    my $ip = shift or return;
    my $dbh = $self->dbh;

    my $sth = $dbh->prepare_cached(q/SELECT * FROM specimens --/);
    my $specimens = $self->dbh->selectall_arrayref(
        $sth, { Slice => {} },    # this results in an array of hashrefs
    );
    return unless @$specimens;

    my $sth2 = $dbh->prepare_cached(
        q/SELECT * FROM votes WHERE ip_address = ? --/);
    my $votes = $self->dbh->selectall_arrayref(
        $sth2, { Slice => {} },    # this results in an array of hashrefs
        $ip
    );

    my @winners = shuffle @$specimens;
    my @losers = shuffle @$specimens;

    OUTERLOOP:
    for my $w (@winners) {

        INNERLOOP:
        for my $l (@losers) {

            next INNERLOOP if ($l->{specimen_id} == $w->{specimen_id});

            # check if 
            if ( first {
                ($w->{specimen_id} == $_->{winner} and $l->{specimen_id} == $_->{loser})
             or ($w->{specimen_id} == $_->{loser}  and $l->{specimen_id} == $_->{winner})
                    } @$votes
            ) {
                next INNERLOOP
            }

            # weve found a pair that havent been voted for
            return ($l, $w)

        }

    }

    return

}

=head2 get_winning_specimens($limit)

Retrieves the top $limit voted specimens, or as many as are available
and returns them in descending order.

Any tied places will all be returned, which will  result in the number
of returned specimens being being greater than $limit.

So if there are no tied positions, the number of returned items will
be $limit or less (less if there arent $limit specimens)

If there are tied positions, the number of returned items will be
$limit + number of tied items. Which could theoretically be the
entire specimens catalog.

Each specimen will also include the number of votes it recieved.

=cut

sub get_winning_specimens {

    my $self = shift;
    my $limit = shift or return;

    my $sth = $self->dbh->prepare_cached(
        q/SELECT count(*) AS votes, specimens.*,
            photographers.full_name
        FROM votes
            INNER JOIN specimens
                ON specimens.specimen_id = votes.winner
            INNER JOIN photographers
                ON specimens.photographer_id = photographers.photographer_id
        GROUP BY winner
        ORDER BY votes DESC
        LIMIT ? --/);

    my $results = $self->dbh->selectall_arrayref(
        $sth,
        { Slice => {} },    # this results in an array of hashrefs
        ( $limit ) # bind values, yes arrays in arrays is pointless, but braces for emphasis
    )
    or die $self->dbh->errstr;

    return unless @$results;
    return wantarray ? @$results : $results;

}

=head2 place_vote

=cut

sub place_vote {

    my $self   = shift;
    my $winner = shift or return;
    my $loser  = shift or return;
    my $ip     = shift or return;

    my $sth = $self->dbh->prepare_cached(
        q/INSERT INTO votes (winner,loser,ip_address)
            VALUES (?,?,?) --/);

    return $sth->execute($winner, $loser, $ip)

}

=head2 username_taken

Checks if a username is taken, returns true if taken otherwise
returns false if its available

=cut

sub username_taken {

    my $self = shift;
    my $name = shift or return;

    my $sth = $self->dbh->prepare_cached(q|SELECT * FROM photographers WHERE username = ? LIMIT 1 --|);

    my $results = $self->dbh->selectall_arrayref(
        $sth,
        { Slice => {} },    # this results in an array of hashrefs
        ( $name ) # bind values, yes arrays in arrays is pointless, but braces for emphasis
    )
    or die $self->dbh->errstr;

    return scalar @$results

}

=head1 AUTHOR

Dean Hamstead,,,

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
