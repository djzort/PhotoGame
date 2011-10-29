package PhotoGame::Controller::Root;
use Moose;
use namespace::autoclean;
use File::Spec;
use File::Temp qw(tempfile);
use List::Utils qw(first);

BEGIN { extends 'Catalyst::Controller::HTML::FormFu' }

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm
#
__PACKAGE__->config(
                    namespace => '',
                    default_action_use_path => 1
                    );

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

sub default :Path {
    my ( $self, $c ) = @_;
    $c->response->body( 'Page not found' );
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
    $c->stash->{total_votes} = $c->model('DB')->get_total_votes();

}

## End of Catalyst Standard Stuff

=head2 gallery

Views all the images as a gallery type of thing

=cut

sub gallery : Path('gallery') : Args(0) {

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

sub login : Path('login') : Args(0) : FormConfig {

    my ( $self, $c ) = @_;

    if (my $me = $c->session->{iam}) {

        $c->stash->{message} = sprintf('You\'re already logged in as %s, go play!', $me->{full_name});
        $c->detach('message');

    }

}

sub login_FORM_RENDER {

}

sub login_FORM_NOT_SUBMITTED {

}

sub login_FORM_VALID {

    my ( $self, $c ) = @_;

    if ( my $me = $c->model('DB')->check_user(
        $c->req->param('username'),
        $c->req->param('password')) ) {

        $c->session->{iam} = $me;
        $c->stash->{message} = sprintf('Welcome %s, lets play!', $me->{full_name});
        $c->detach('message');

    } else {

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

sub logout : Path('logout') : Args(0) {

    my ( $self, $c ) = @_;

    if (my $me = $c->session->{iam}) {

        $c->session->{iam} = undef;
        $c->stash->{message} = 'Logged out!';
        $c->detach('message');

    }

    $c->stash->{message} = 'Not logged in?';
    $c->detach('message');

}

=head2 message

Just shows a generic message

=cut

sub message : Local {

    my ( $self, $c ) = @_;
    $c->stash->{template} = 'message.tt';

}

=head2 register

This is where the photographers will register to play the game!

=cut

sub register : Path('register') : Args(0) : FormConfig {

    # config is root/forms/register.yaml

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

sub results : Path('results') : Args(0) {

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

sub upload : Path('upload') : Args(0) : FormConfig {

    # config is root/forms/upload.yaml

    my ( $self, $c ) = @_;

    unless ( $c->session->{iam} ) {

        $c->stash->{message} = 'You must be logged in to play the game!';
        $c->detach('message');

    }

    unless ( $c->model('DB')->get_setting('submissions_open') ) {

        $c->stash->{message} = 'Submissions arent yet open or have closed';
        $c->detach('message');

    }

    $c->stash->{maxsubmissions} = $c->model('DB')->get_setting('max_submissions');
    my @specimens = $c->model('DB')->get_my_specimen(
                                $c->session->{iam}->{photographer_id});
    my @queue = $c->model('DB')->get_my_queue(
                                $c->session->{iam}->{photographer_id});

    # generate forms to go along with images
    for my $item (@specimens) {

        my $form = $self->form;
        $form->load_config_file('upload_image.yml');
        $form->query( $c->request );
        $form->process;

        my $new = $form->element({  type  => 'Hidden',
                                    name  => 'specimen_id',
                                    value => $item->{specimen_id},
                                });

        my $position = $form->get_all_element({ type => 'Submit',
                                                name => 'submit' });

        $form->insert_before( $new, $position );

        $item->{form} = $form;

    }

    $c->stash->{specimens} = \@specimens;
    $c->stash->{queue} = \@queue;

}

sub upload_FORM_RENDER {

}

sub upload_FORM_NOT_SUBMITTED {

}

sub upload_FORM_VALID {

    my ( $self, $c ) = @_;

    my $me = $c->session->{iam};
    my $photo = $c->request->upload('photo');
    my ( $suffix ) = $photo->filename =~ m{(\.\w+)$};
    $suffix ||= 'jpg';

    my ( $fh, $filename );

    eval {
        ( $fh, $filename ) = tempfile(
           'FGXXXXXXXXXXXXXXXXXXXXXX',
            SUFFIX => lc($suffix),
            UNLINK => 0,
            DIR => $c->config->{queuepath}
            );
    };

    if ($@) {

        $c->stash->{error} = "Error writing file: $@";
        return 1

    }

    if ( $photo->copy_to( $fh ) ) {

        if ( $c->request->upload('specimen_id') ) {

            unless (grep {} @{$c->stash->{specimens}}) {
                $c->stash->{message} = 'You dont own that specimen';
                $c->detach('message');
            }

        }

        $c->model('DB')->add_queue(
                            $photo->filename,
                            $filename,
                            $me->{photographer_id},
                            $c->request->upload('specimen_id')
                            );

        $c->stash->{message} = 'file submitted to processing queue';

    } else {

        $c->stash->{error} = 'failed to save file';

    }

}

sub upload_FORM_NOT_VALID {

    my ( $self, $c ) = @_;
    #$c->stash->{template} = 'upload.tt';
    $c->stash->{message} = 'form not valid';

}

=head2 vote

This is where people can vote on the assets

=cut

sub vote : Path('vote') : Args(0) {

    # config is root/forms/vote.yaml

    my ( $self, $c ) = @_;

    unless ( $c->model('DB')->get_setting('voting_open') ) {

        $c->stash->{message} = 'Voting is closed';
        $c->detach('message');

    }
    else {

        if ($c->req->param('winner') and $c->req->param('loser')) {
    
            if ($c->model('DB')->place_vote($c->req->param('winner'),$c->req->param('loser'), $c->req->address)) 
            {
                $c->stash->{message} = 'Vote placed'
            }
            else {
                $c->stash->{message} = 'Vote failed?'
            }
    
        }
        elsif ($c->req->param('vote')) {
    
            $c->stash->{message} = 'Vote without winner and loser?'
    
        }

        if (my ($specimen1, $specimen2) =
            $c->model('DB')->get_two_random_specimens($c->req->address))
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

Dean Hamstead,,,

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
