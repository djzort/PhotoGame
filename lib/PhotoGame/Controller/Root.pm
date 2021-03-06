package PhotoGame::Controller::Root;
use Moose;
use namespace::autoclean;
use File::Spec;
use File::Path qw(make_path);
use File::Temp qw(tempfile);
use List::Util qw(first);

BEGIN { extends 'Catalyst::Controller::HTML::FormFu' }

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm
#
__PACKAGE__->config(
    namespace               => '',
    default_action_use_path => 1
);

my $path = PhotoGame->config()->{queuepath}
  or die q|Couldn't find queuepath config option|;

make_path($path) unless -d $path;

=encoding utf-8

=head1 NAME

PhotoGame::Controller::Root - Root Controller for PhotoGame

=head1 DESCRIPTION

A game for LANparties where photographers can submit photos and
be voted the winner.

=head1 METHODS

=head2 index

The root page (/)

=cut

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;

    # nothing to see here

}

=head2 default

Standard 404 error page

=cut

sub default : Path {
    my ( $self, $c ) = @_;
    $c->response->body('Page not found');
    $c->response->status(404);
}

=head2 end

Attempt to render a view, if needed.

=cut

sub end : ActionClass('RenderView') {

    my ( $self, $c ) = @_;

    # shove my identity in to the stash if i am logged in
    $c->stash->{me} = $c->session->{iam}
      if $c->session->{iam};

    # total number of votes taken
    $c->stash->{total_votes} = $c->model('DB')->get_total_votes() || 0;

}

## End of Catalyst Standard Stuff

=head2 gallery

Views all the images as a gallery type of thing

=cut

sub gallery : Local : Args(0) {

    my ( $self, $c ) = @_;

    if ( $c->model('DB')->get_setting('voting_open') ) {

        $c->stash->{message} = 'Gallery closed while voting is open';
        $c->detach('message');

    }

    $c->stash->{specimens} = $c->model('DB')->get_all_specimens();

}

=head2 login

Allows people to log in and then be able to submit photos to the game

=cut

sub login : Local : Args(0) : FormConfig {

    my ( $self, $c ) = @_;

    if ( my $me = $c->session->{iam} ) {

        $c->stash->{message} =
          sprintf( 'You\'re already logged in as %s, go play!',
            $me->{full_name} );
        $c->detach('message');

    }

}

sub login_FORM_RENDER {

}

sub login_FORM_NOT_SUBMITTED {

}

sub login_FORM_VALID {

    my ( $self, $c ) = @_;

    if ( my $me =
        $c->model('DB')
        ->check_user( $c->req->param('username'), $c->req->param('password') ) )
    {

        $c->session->{iam} = $me;
        $c->stash->{message} =
          sprintf( 'Welcome %s, lets play!', $me->{full_name} );
        $c->detach('message');

    }
    else {

        $c->stash->{error} = 'Failed to log in';

    }

}

sub login_FORM_NOT_VALID {

    my ( $self, $c ) = @_;
    $c->stash->{error} = 'Failed to log in';

}

=head2 logout

Logs you out if logged in

=cut

sub logout : Local : Args(0) {

    my ( $self, $c ) = @_;

    if ( my $me = $c->session->{iam} ) {

        $c->session->{iam}   = undef;
        $c->stash->{message} = 'Logged out!';
        $c->detach('message');

    }

    $c->stash->{message} = 'Not logged in?';
    $c->detach('message');

}

=head2 message

Just shows a generic message

=cut

sub message : Private {

    my ( $self, $c ) = @_;
    $c->stash->{template} = 'message.tt';

}

=head2 register

This is where the photographers will register to play the game!

=cut

sub register : Local : Args(0) : FormConfig {

    # config is root/forms/register.yml

    my ( $self, $c ) = @_;

    #$c->stash->{template} = 'register.tt';

    unless ( $c->model('DB')->get_setting('registration_open') ) {

        $c->stash->{message} = 'Registrations are closed';
        $c->detach('message');

    }

}

sub register_FORM_RENDER {

}

sub register_FORM_NOT_SUBMITTED {

}

sub register_FORM_VALID {

    my ( $self, $c ) = @_;

    $c->model('DB')->create_photographer(
        username    => $c->req->param('username'),
        password    => $c->req->param('password'),
        full_name   => $c->req->param('full_name'),
        email_addr  => $c->req->param('email_addr'),
        creation_ip => $c->req->address,
    );

    $c->stash->{message} = 'user created';
    $c->detach('message');

}

sub register_FORM_NOT_VALID {

    my ( $self, $c ) = @_;
    $c->stash->{error} = 'Submission failed, see comments above';

}

=head2 results

Views all the images as a resilts page type of thing

=cut

sub results : Local : Args(0) {

    my ( $self, $c ) = @_;

    unless ( $c->model('DB')->get_setting('results_open') ) {

        $c->stash->{message} = 'Results closed while voting is open';
        $c->detach('message');

    }

    $c->stash->{specimens} = $c->model('DB')->get_winning_specimens(10);

}

=head2 upload

This is where the photographers will upload their photos

We dont want the webserver to have to resize them, so all we do is
queue them up

=cut

sub upload : Local : Args(0) : FormConfig {

    # config is root/forms/upload.yml

    my ( $self, $c ) = @_;

    my $form = $c->stash->{form};
    my $me   = $c->session->{iam};

    unless ($me) {

        $c->stash->{message} = 'You must be logged in to play the game!';
        $c->detach('message');

    }

    unless ( $c->model('DB')->get_setting('submissions_open') ) {

        $c->stash->{message} = 'Submissions arent yet open or have closed';
        $c->detach('message');

    }

    ## Load the queue

    my @queue =
      $c->model('DB')->get_my_queue( $c->session->{iam}->{photographer_id} );
    $c->stash->{queue} = \@queue;

    ## Load specimens

    $c->stash->{maxsubmissions} =
      $c->model('DB')->get_setting('max_submissions');
    my @specimens =
      $c->model('DB')->get_my_specimen( $c->session->{iam}->{photographer_id} );
    $c->stash->{specimens} = \@specimens;

    ## First try to delete

    my $delete_form = $self->form;
    $delete_form->load_config_file('upload_delete.yml');
    $delete_form->process();

    if ( $delete_form->submitted_and_valid ) {

        if ( my $specimen_id = $c->request->param('specimen_id') ) {

            if ( first { $specimen_id == $_->{specimen_id} } @specimens ) {

                $c->model('DB')->delete_specimen(
                    specimen_id     => $specimen_id,
                    photographer_id => $me->{photographer_id},
                );

                $c->stash->{message} = 'Specimen deleted';

                @specimens =
                  grep { $specimen_id != $_->{specimen_id} } @specimens;

            }
            else {

                $c->stash->{message} = 'You dont own that specimen';
                $c->detach('message');

            }

        }

    }

    ## Second try uploads

    if ( $form->submitted_and_valid ) {

        if (
            ( scalar @specimens + scalar @queue ) >= $c->stash->{maxsubmissions} )
        {
            $c->stash->{message} = 'Maximum submissions reached (submitted item ignored)';
            $c->detach('message');
        }

        my $photo = $c->request->upload('photo');
        my ($suffix) = $photo->filename =~ m{(\.\w+)$};
        $suffix ||= 'jpg';

        my ( $fh, $filename );

        eval {
            ( $fh, $filename ) = tempfile(
                'PGXXXXXXXXXXXXXXXXXXXXXX',
                SUFFIX => lc($suffix),
                UNLINK => 0,
                DIR    => $c->config->{queuepath}
            );
        };

        if ($@) {

            $c->stash->{error} = "Error writing file: $@";
            return 1

        }

        if ( $photo->copy_to($fh) ) {

            $c->model('DB')->add_queue(
                $photo->filename, $filename,
                $me->{photographer_id},
                $c->request->upload('specimen_id')
            );

            $c->stash->{message} = 'File submitted to processing queue';

            # reload queue if we messed with it, note this is referenced in the stash already
            @queue =
                $c->model('DB')->get_my_queue( $c->session->{iam}->{photographer_id} );

        }
        else {

            $c->stash->{error} = 'Failed to save file';

        }

    }
    elsif ( $form->submitted ) {

        $c->stash->{message} = 'Form not valid';

    }

    ## Finale, generate forms to go along with images
    for my $item (@specimens) {

        my $form = $self->form;
        $form->load_config_file('upload_delete.yml');

        my $new = $form->element(
            {
                type  => 'Hidden',
                name  => 'specimen_id',
                value => $item->{specimen_id},
            }
        );

        my $position = $form->get_all_element(
            {
                type => 'Submit',
                name => 'submit'
            }
        );

        $form->insert_before( $new, $position );

        $item->{form} = $form;

    }

}

=head2 vote

This is where people can vote on the assets

=cut

sub vote : Local : Args(0) {

    # config is root/forms/vote.yml

    my ( $self, $c ) = @_;

    unless ( $c->model('DB')->get_setting('voting_open') ) {

        $c->stash->{message} = 'Voting is closed';
        $c->detach('message');

    }
    else {

        if ( $c->req->param('winner') and $c->req->param('loser') ) {

            if (
                $c->model('DB')->place_vote(
                    $c->req->param('winner'), $c->req->param('loser'),
                    $c->req->address
                )
              )
            {
                $c->stash->{message} = 'Vote placed';
            }
            else {
                $c->stash->{message} = 'Vote failed?';
            }

        }
        elsif ( $c->req->param('vote') ) {

            $c->stash->{message} = 'Vote without winner and loser?'

        }

        if ( my ( $specimen1, $specimen2 ) =
            $c->model('DB')->get_two_random_specimens( $c->req->address ) )
        {

            $c->stash->{specimen1} = $specimen1;
            $c->stash->{specimen2} = $specimen2;

        }
        else {

            $c->stash->{message} .= ' No photos left to vote for';
            $c->detach('message');

        }

    }

}

=head1 AUTHOR

Dean Hamstead C<< <dean@fragfest.com.au> >>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
