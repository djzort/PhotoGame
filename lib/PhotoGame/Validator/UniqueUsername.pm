package PhotoGame::Validator::UniqueUsername;
use strict; use warnings;
use parent 'HTML::FormFu::Validator';

sub validate_value {
    my ( $self, $value, $params ) = @_;
    my $c = $self->form->stash->{context};

    if ($c->model('DB')->username_taken($value)) {

        die HTML::FormFu::Exception::Validator->new({
            message => 'username taken',
        });

    }

    return 1

}

1


__END__

=head1 NAME

PhotoGame::Validator::UniqueUsername

=head1 SYNOPSIS

This is a custom data validator for HTML::FormFu, it ensures that a
username is not already taken

=head1 DESCRIPTION

As per synopsis

=head1 METHODS

=head2 validate_value

As per the HTML::FormFu requirements

=head1 AUTHOR

Dean Hamstead,,,

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
