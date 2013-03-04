package HTML::Tree::QueryTest;
use strict;
use warnings;

use Data::Dumper;
use Error qw(:try);
use Carp qw(confess);
use Test::More qw(no_plan);
use Test::Deep;
use Test::NoWarnings;

use base 'Test::Class';

BEGIN: { 
    use_ok("HTML::TreeBuilder");
    use_ok("CSS::Selector::Parser", 'parse_selector');
    use_ok("HTML::Tree::Query", "query_dom");
}

sub startup : Test(startup) {
    my ($self) = @_;
    $self->{content} = join("", <DATA>);
}

sub setup : Test(setup) {
    my ($self) = @_;
    $self->{tree} = HTML::TreeBuilder->new_from_content($self->{content});
}

sub _test_element {
    my ($e, $tag, $attrs_hash) = @_;
    isa_ok($e, "HTML::Element");
    is($e->tag(), $tag, "Tag should be $tag");
    foreach my $a (keys %$attrs_hash) {
        is($e->attr($a), $attrs_hash->{$a});
    }
}

sub query_by_tag_name : Test(no_plan) {
    my ($self) = @_;
    my $head = query_dom($self->{tree}, "input");
    is(ref($head), "ARRAY", "returns an array");
    is(scalar(@$head), 2, "found two input tags");

    _test_element($head->[0], 'input', {
        type => 'checkbox', id => 'check_me',
        name => 'check_me', checked => 'checked',
    });
    _test_element($head->[1], 'input', {
        type => 'text', name => 'some_text', size => 20,
    });
}

sub query_by_name_attr : Test(no_plan) {
    my ($self) = @_;
    my $inputs = query_dom($self->{tree}, '[name="some_text"]');
    is(scalar(@$inputs), 1, "found one input tags");
    _test_element($inputs->[0], 'input', {
        type => 'text', name => 'some_text', size => 20,
    });
}

sub query_by_class_name : Test(no_plan) {
    my ($self) = @_;

    # element w/ only one class
    my $elements = query_dom($self->{tree}, '.content_area');
    is(scalar(@$elements), 1);
    _test_element($elements->[0], 'div', { class => 'content_area' });
    
    # element that has multiple class names
    $elements = query_dom($self->{tree}, '.float_right');
    is(scalar(@$elements), 1);
    _test_element($elements->[0], 'div', {
        class => 'float_right main_section class2 class3'
    });

    #multiple elements w/ same class
    $elements = query_dom($self->{tree}, '.class2');
    is(scalar(@$elements), 2);
    _test_element($elements->[0], 'div', {
        class => 'float_right main_section class2 class3'
    });
    _test_element($elements->[1], 'div', {
        class => 'float_left news_section class2'
    });
}

sub query_by_id : Test(no_plan) {
    my ($self) = @_;
    my $elements = query_dom($self->{tree}, '#content_div');
    is(scalar(@$elements), 1);
    _test_element($elements->[0], 'div', {
        id => 'content_div', class => 'content_area',
    });
}

sub query_by_attr : Test(no_plan) {
    my ($self) = @_;

    # [type=checkbox]
    my $elements = query_dom($self->{tree}, '[type="checkbox"]');
    is(scalar(@$elements), 1);
    _test_element($elements->[0], 'input', {
        type => 'checkbox', id => 'check_me',
        name => 'check_me', checked => 'checked',
    });

    # input[type=text]
    $elements = query_dom($self->{tree}, 'input[type="text"]');
    is(scalar(@$elements), 1);
    _test_element($elements->[0], 'input', {
        type => 'text', name => 'some_text', size => 20,
    });

    # input[size=20]
    $elements = query_dom($self->{tree}, 'input[size="20"]');
    is(scalar(@$elements), 1);
    _test_element($elements->[0], 'input', {
        type => 'text', name => 'some_text', size => 20,
    });

    # [data-fake=fake] (multiple tags of different types match)
    $elements = query_dom($self->{tree}, '[data-fake="fake"]');
    is(scalar(@$elements), 2);
    _test_element($elements->[0], 'form', {
        id => 'some_form', 'data-fake' => 'fake',
    });
    _test_element($elements->[1], 'ul', {
        class => 'news_list', 'data-fake' => 'fake',
    });

    # form[data-fake=fake] (matches just the form element)
    $elements = query_dom($self->{tree}, 'form[data-fake="fake"]');
    is(scalar(@$elements), 1);
    _test_element($elements->[0], 'form', {
        id => 'some_form', 'data-fake' => 'fake',
    });
}

sub query_with_commas : Test(no_plan) {
    my ($self) = @_;
    my $elements = query_dom($self->{tree}, 'form, #content_div');
    is(scalar(@$elements), 2);
    _test_element($elements->[0], 'form', {
        id => 'some_form', 'data-fake' => 'fake',
    });
    _test_element($elements->[1], 'div', {
        id => 'content_div', class => 'content_area',
    });

    # how about one where part does not match?
    $elements = query_dom($self->{tree}, 'form, #bad_selector');
    is(scalar(@$elements), 1);
    _test_element($elements->[0], 'form', {
        id => 'some_form', 'data-fake' => 'fake',
    });
}

sub query_with_descendant_combinator : Test(no_plan) {
    my ($self) = @_;
    my $elements = query_dom($self->{tree}, 'div#content_div label');
    is(scalar(@$elements), 2);
    _test_element($elements->[0], 'label', {for => 'check_me'});
    _test_element($elements->[0], 'label', {});
}

sub query_with_child_combinator : Test(no_plan) {
    my ($self) = @_;
    my $elements = query_dom($self->{tree}, 'body>div');
    is(scalar(@$elements), 1);
    _test_element($elements->[0], 'div', {
        id => 'content_div', class => 'content_area',
    });
}

sub query_with_adjacent_sybling_combinator : Test(no_plan) {
    my ($self) = @_;
    my $elements = query_dom($self->{tree}, '[type="checkbox"]+label');
    is(scalar(@$elements), 2);
    _test_element($elements->[0], 'label', {for => 'check_me'});
    _test_element($elements->[0], 'label', {});

    $elements = query_dom($self->{tree}, 'div.class3+div');
    is(scalar(@$elements), 1);
    _test_element($elements->[0], 'div', {
        class => "float_left news_section class2"
    });
}

# TODO -
# lots of combinator tests... try to break it

# TODO -
# pseudo? do we need this?
#   :link, :focus, :first-letter, :first-line, :first-child, :before, :after, :lang(it)
#   no need for :visited, :active, or :hover

# TODO - support for html5 elements - section/aside/navigation/etc
# maybe just need to update HTML::Parser...

__PACKAGE__->runtests();

1;

__DATA__
<html>
    <head>
        <title>HTML::DOM::Query Test</title>
    </head>
    <body>
        <div id="content_div" class="content_area">
            <div class="float_right main_section class2 class3">
                <form id="some_form" data-fake="fake">
                    <input type="checkbox" id="check_me" name="check_me" checked />
                    <label for="check_me">Check Me!</label>
                    <label>Enter Text:</label>
                    <input type="text" name="some_text" size="20" />
                </form>
            </div>
            <div class="float_left news_section class2">
                <ul class="news_list" data-fake="fake">
                    <li>News Item 1</li>
                    <li>News Item 2</li>
                </ul>
            </div>
        </div>
    </body>
</html>
