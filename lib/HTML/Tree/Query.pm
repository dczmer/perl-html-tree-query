package HTML::Tree::Query;
use strict;
use warnings;

our $VERSION = '0.001';

=pod

=head1 NAME

HTML::Tree::Query - select elements from an L<HTML::Tree> object using
jQuery-like selectors.

=head1 VERSION

Version 0.001

=head1 SYNOPSIS

    use HTML::Tree::query qw(query_dom);

    $text_elements = query_dom($tree, "tbody td>input[type=text]");

    foreach my $html_element (@$text_elements) {
        print $html_element->as_HTML();
    }

=head1 DESCRIPTION

This module allows you to use some jquery-like selectors to query an 
L<HTML::Tree> object and get back an array-ref of L<HTML::Element>
objects that match the criteria.

For unit testing and mechanize/browser tests, it is important to
have an easy to use method of validating HTML documents.

L<Mojo::DOM> is really cool but it requires the entire Mojolicious
framework as a dependency.

You could also use some of the various modules that implement
XPath-style querying but most of the legacy HTML I parse is not
valid XML/XHTML.

=head1 DEPENDENCIES

=over

=item *

L<HTML::TreeBuilder>

=item *

L<CSS::Selector::Parser>

=back

=head1 METHODS

=over

=cut

use HTML::Tree;
use CSS::Selector::Parser qw(parse_selector);

use base 'Exporter';
our @EXPORT_OK = qw(query_dom);

my %combinators = (
    ' ' => \&_match_descendants,
    '>' => \&_match_child,
    '+' => \&_match_adjacent_sybling,
    # not implemented
    #'~' => \&_match_general_sybling,
);

=item query_dom

Given an HTML tree object and a selector string, find all matching
nodes in the tree.

=cut

sub query_dom {
    my ($tree, $selector) = @_;
    my @rules_set = parse_selector($selector);
    my @result = ();
    foreach my $selector_part (@rules_set) {
        push @result => _match_nodes($tree, @$selector_part);
    }
    return [_dedupe_nodes(@result)];
}

sub _dedupe_nodes {
    my (@nodes) = @_;
    my @deduped = ();
    foreach my $n (@nodes) {
        my $found = 0;
        foreach my $d (@deduped) {
            if ($d->idf() eq $n->idf()) {
                $found = 1;
            }
        }
        unless ($found) {
            push @deduped => $n;
        }
    }
    return @deduped;
}

sub _match_nodes {
    my ($node, @rules) = @_;
    my @result = ();
    if (scalar(@rules)) {
        my $r = shift(@rules);
        my $comb = $r->{combinator}||' ';
        my $func = $combinators{$comb} || die("Unknown combinator: $comb");
        my $criteria = _build_criteria($r);
        foreach my $m ($func->($node, $criteria)) {
            push @result => _match_nodes($m, @rules);
        }
    }
    else {
        push @result => $node;
    }
    return @result;
}

sub _build_criteria {
    my ($selector_part) = @_;
    my %criteria = ();
    if ($selector_part->{element}) {
        $criteria{_tag} = $selector_part->{element} 
    }
    if ($selector_part->{id}) {
        $criteria{id} = $selector_part->{id};
    }
    if ($selector_part->{class}) {
        $criteria{class} = qr/\b$selector_part->{class}\b/;
    }
    if ($selector_part->{attr}) {
        foreach my $a (keys %{$selector_part->{attr}}) {
            $criteria{$a} = $selector_part->{attr}->{$a}->{'='};
        }
    }
    if ($selector_part->{pseudo}) {

    }
    return \%criteria;
}

sub _match_descendants {
    my ($node, $criteria) = @_;
    if ($criteria->{_tag} && $criteria->{_tag} eq '*') {
        return ($node->descendants());
    }
    return ($node->look_down(%$criteria));
}

sub _match_child {
    my ($node, $criteria) = @_;
    if ($criteria->{_tag} && $criteria->{_tag} eq '*') {
        return ($node->look_down(sub { $_[0]->parent() == $node }));
    }
    return (
        $node->look_down(%$criteria, sub {
            $_[0]->parent() == $node;
        })
    );
}

sub _match_adjacent_sybling {
    my ($node, $criteria) = @_;
    my $parent = $node->parent() or return ();
    if ($criteria->{_tag} && $criteria->{_tag} eq '*') {
        return (
            $parent->look_down(sub {
                $_[0] != $node && $_[0]->parent() == $parent;
            })
        );
    }
    return (
        $parent->look_down(%$criteria, sub {
            $_[0] != $node && $_[0]->parent() == $parent;
        })
    );
}

# TODO -
# match any direct descendant of any instance of the previous selector
# will need to know the previous selector for this...
sub _match_general_sybling {
    my ($node, $criteria) = @_;
    die("Not implemented");
}

=back

=head1 SEE ALSO

=over

=item *

L<HTML::TreeBuilder> - ues this to build a tree object to query.

=item *

L<HTML::Tree> - this is what TreeBuilder produces and this module
operates on; inherits from L<HTML::Element> so it has the same methods
available.

=item *

L<HTML::Element> - the tree is made up of element objects. This is what
your query results will be, an array-ref of L<HTML::Element> objects.

=item *

L<CSS::Selector::Parser> - I used this module to parse the selector
strings into criteria that is used to traverse the tree. It also
chains rules together with combinators, which control how this module
matches elements from one rule to the next.

=back

=head1 BUGS / MISSING FEATURES

Pseudo classes, like :before and :after, are not implemented yet.
I don't see much use for :hover, :visited, etc in this context.

The specification for operator precedence with complicated querys is
not clearly defined.

For example:

    div>h1,h2

Does it return all h1's or h2's that are under a div? Or does it
return all h1's under a div, and all h2's in the tree?

This implementation does the latter and some quick testing with jquery
seems to indicate that this is the expected behavior.

=head1 AUTHOR

    David Czmer <dczmer@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by David Czmer <dczmer@gmail.com>.

This is free software; you can redistribute it and/or modify it under
the same terms as perl itself.

=cut

1;  
