package HTML::Tree::QuerySmokeTest;
use strict;
use warnings;

use Data::Dumper;
use Error qw(:try);
use Carp qw(confess);
use Test::More qw(no_plan);
use Test::Deep;
use Test::NoWarnings;

use base 'Test::Class';

# 1. create a large, complex html document in DATA
# 2. load it into a tree
# 3. run a shit-ton of selections and try to break it

BEGIN: { 
    use_ok("HTML::TreeBuilder");
    use_ok("HTML::Tree::Query", qw(query_dom));
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

sub simple_selector_test : Test(no_plan) {
    my ($self) = @_;
    # colgroup is comented out, should nto find any
    my $elements = query_dom($self->{tree}, "colgroup");
    is(scalar(@$elements), 0);
    # #commits_section
    $elements = query_dom($self->{tree}, "#newBranchSelection");
    is(scalar(@$elements), 1);
    _test_element($elements->[0], 'select', {
        id => 'newBranchSelection', 'data-bind' => "options: branches", size => 6
    });
    # .td_check
    $elements = query_dom($self->{tree}, ".td_check");
    is(scalar(@$elements), 2);
    _test_element($elements->[0], 'th', { class => 'td_check' });
    _test_element($elements->[1], 'input', {
        class => 'td_check', type => 'checkbox',
        'data-bind' => "checked: isChecked",
    });
    # th.td_check
    $elements = query_dom($self->{tree}, "th.td_check");
    is(scalar(@$elements), 1);
    _test_element($elements->[0], 'th', { class => 'td_check' });
    # input.td_check
    $elements = query_dom($self->{tree}, "input.td_check");
    is(scalar(@$elements), 1);
    _test_element($elements->[0], 'input', {
        class => 'td_check', type => 'checkbox',
        'data-bind' => "checked: isChecked",
    });
    # some selectors that do not match
    $elements = query_dom($self->{tree}, "td.td_check");
    is(scalar(@$elements), 0);
    $elements = query_dom($self->{tree}, '[type="hidden"]');
    is(scalar(@$elements), 0);
    # dont ever do this
    $elements = query_dom($self->{tree}, "*");
    is(scalar(@$elements), 63);
}

sub comma_selector_test : Test(no_plan) {
    my ($self) = @_;
    # two things that both exist
    my $elements = query_dom($self->{tree}, "label,thead");
    is(scalar(@$elements), 2);
    _test_element($elements->[0], 'label', { for => 'updateMessages' });
    _test_element($elements->[1], 'thead', {});
    # one that does, one does not exist
    $elements = query_dom($self->{tree}, "label,blink");
    is(scalar(@$elements), 1);
    _test_element($elements->[0], 'label', { for => 'updateMessages' });
    # none exist
    $elements = query_dom($self->{tree}, "article,blink");
    is(scalar(@$elements), 0);
}

sub descendants_selector_test : Test(no_plan) {
    my ($self) = @_;
    my $elements = query_dom($self->{tree}, "div br");
    is(scalar(@$elements), 6);
    # div.commits_section input
    $elements = query_dom($self->{tree}, "div.commits_section input");
    is(scalar(@$elements), 2);
    _test_element($elements->[0], 'input', {
        type => 'text', 'data-bind' => 'value: authorFilter',
    });
    _test_element($elements->[1], 'input', {
        class => 'td_check', type => 'checkbox',
        'data-bind' => 'checked: isChecked',
    });
    # table input,thead
    $elements = query_dom($self->{tree}, "table input,thead");
    is(scalar(@$elements), 2);
    _test_element($elements->[0], 'input', {
        class => 'td_check', type => 'checkbox',
        'data-bind' => 'checked: isChecked',
    });
    _test_element($elements->[1], 'thead', {});
    # more levels
    $elements = query_dom($self->{tree}, "html body div p a");
    is(scalar(@$elements), 1);
    _test_element($elements->[0], 'a', {
        href => '#', 'data-bind' => "click: showBranchSelectionDialog",
    });
    # then some that do not exist
    $elements = query_dom($self->{tree}, "table section");
    is(scalar(@$elements), 0);
    # *
    $elements = query_dom($self->{tree}, "table *");
    is(scalar(@$elements), 15);
    $elements = query_dom($self->{tree}, "* br");
    is(scalar(@$elements), 6);
}

sub child_selector_test : Test(no_plan) {
    my ($self) = @_;
    my $elements = query_dom($self->{tree}, "div.branches_section>h3");
    is(scalar(@$elements), 2);
    # one that _would_ match as descendant, but not as direct child
    $elements = query_dom($self->{tree}, "table>tr");
    is(scalar(@$elements), 0);
    # multiple child selectors
    $elements = query_dom($self->{tree}, "html>body>div>select");
    is(scalar(@$elements), 2);
    _test_element($elements->[0], 'select', {
        id => 'newBranchSelection', 'data-bind' => 'options: branches',
        size => 6,
    });
    _test_element($elements->[1], 'select', {
        'data-bind' => 'options: branches, value: selectedBranch, disable: disableActions',
        size => 18,
    });
    # NOTE - commas
    # so, we are comparing this to what happens when we try it in jquery
    # all h3's under div.branches_seciton and all p's in the document
    # there does not seem to be a consensus on order of operations when
    # combining css combinators.
    $elements = query_dom($self->{tree}, "div.branches_section>h3,p");
    is(scalar(@$elements), 5);
    _test_element($elements->[0], 'h3', {});
    _test_element($elements->[1], 'h3', {});
    _test_element($elements->[2], 'p', {});
    _test_element($elements->[3], 'p', {
        'data-bind' => "visible: displayCommits().length == 0",
    });
    _test_element($elements->[4], 'p', { id => 'picklog' });
    # *
    $elements = query_dom($self->{tree}, "div.branches_section>*");
    is(scalar(@$elements), 8);
    $elements = query_dom($self->{tree}, "*>p");
    is(scalar(@$elements), 3);
}

sub adjacent_sybling_selector_test : Test(no_plan) {
    my ($self) = @_;
    my $elements = query_dom($self->{tree}, ".td_check+th");
    is(scalar(@$elements), 4);
    $elements = query_dom($self->{tree}, "thead+tbody");
    is(scalar(@$elements), 1);
    $elements = query_dom($self->{tree}, "input#updateMessages+br");
    is(scalar(@$elements), 4);
    # multiple
    $elements = query_dom($self->{tree}, ".td_commit+td>input");
    is(scalar(@$elements), 1);
    _test_element($elements->[0], 'input', {
        class => "td_check", type => 'checkbox',
        'data-bind' => "checked: isChecked",
    });
    # commas...
    # see note from child_selecto_test...
    $elements = query_dom($self->{tree}, "h3+p,label");
    is(scalar(@$elements),  3);
    _test_element($elements->[0], 'p', {});
    _test_element($elements->[1], 'p', {
        'data-bind' => 'visible: displayCommits().length == 0'
    });
    _test_element($elements->[2], 'label', { for => 'updateMessages' });
    # *
    $elements = query_dom($self->{tree}, "h3+*");
    is(scalar(@$elements), 11);
    $elements = query_dom($self->{tree}, "*+h3");
    is(scalar(@$elements), 3);
}

# Someday...
# sub general_sybling_selector_test : Test(no_plan) {
#
# }
#
#sub super_crazy_complex_selector_tests_round_1 : Test(no_plan) {
#    # mix all combinators
#}

__PACKAGE__->runtests();

1;

__DATA__
<!DOCTYPE html>
<html>
    <head>
        <title>Builderer</title>
        <link rel="stylesheet" type="text/css" href="/static/css/cupertino/jquery-ui-1.9.2.custom.css" />
        <link rel="stylesheet/less" type="text/css" href="/static/css/builderer.less" />
        <script type="text/javascript" src="/static/js/knockout-2.2.0rc.js"></script>
        <script type="text/javascript" src="/static/js/less-1.3.3.min.js"></script>
        <script type="text/javascript" src="/static/js/jquery-1.8.3.js"></script>
        <script type="text/javascript" src="/static/js/jquery-ui-1.9.2.custom.js"></script>
        <script type="text/javascript" src="/static/js/builderer.js"></script>
    </head>
    <body>
        <div id="dialog"></div>
        <div id="branchSelectionDialog">
            <select id="newBranchSelection" data-bind="options: branches" size=6></select>
        </div>
        <div class="error_section" data-bind="visible: errorMessage">
            <span data-bind="text: errorMessage"></span>
        </div>
        <div class="branches_section">
            <h3>Source Branch:</h3>
            <p>Current branch is '<span data-bind="text: currentBranch"></span>'
                (<a href="#" data-bind="click: showBranchSelectionDialog">Change...</a>)
                <br />
                <button data-bind="jqButton: true, click: rebaseMaster, disable: disableActions">Rebase Now</button>
            </p>
            <h3>Destination Branch:</h3>
            <select data-bind="options: branches, value: selectedBranch, disable: disableActions" size=18></select>
            <br />
            <div data-bind="visible: selectedBranch">
                Build tag will be <b data-bind="text: nextTag"></b>
            </div>
            <input id="newBranch" type="text" data-bind="value: newBranchName" size="16"></input>
            <button data-bind="jqButton: true, click: addBranch, disable: disableActions">Add Branch</button>
        </div>
        <div class="commits_section">
            <h3>Select Commits to Include:</h3>
            <p data-bind="visible: displayCommits().length == 0">
                No commits to cherry-pick.
            </p>
            <div data-bind="visible: selectedBranch() && displayCommits().length > 0">
                <span>Author Filter:</span>
                /<input type="text" data-bind="value: authorFilter" size="36"></input>/
            </div>
            <table class="commits_table" data-bind="visible: selectedBranch() && displayCommits().length > 0">
                <!--
                <colgroup>
                    <col width="30px" />
                    <col width="100px" />
                    <col width="180px" />
                    <col width="120px" />
                    <col width="320px" />
                </colgroup>
                -->
                <thead>
                    <tr>
                        <th class="td_check"></th>
                        <th class="td_commit">Commit</th>
                        <th class="td_date">Date</th>
                        <th class="td_author">Author</th>
                        <th class="td_message">Message</th>
                    </tr>
                </thead>
                <tbody data-bind="foreach: displayCommits">
                    <tr>
                        <td><input class="td_check" type="checkbox" data-bind="checked: isChecked"></input></td>
                        <td class="td_commit" data-bind="text: commit.substring(0, 7)"></td>
                        <td class="td_date" data-bind="text: date.substring(0, 19)"></td>
                        <td class="td_author" data-bind="text: author"></td>
                        <td class="td_message" data-bind="text: message"></td>
                    </tr>
                </tbody>
            </table>
        </div>
        <div class="spacer">&nbsp;</div>
        <div class="controls_section">
            <br />
            <button data-bind="jqButton: true, click: cherryPick, disable: disableActions">
                Cherry-Pick Commits
            </button>
            <br />
            <br />
            <input id="updateMessages" type="checkbox" data-bind="checked: updateMessages"></input>
            <label for="updateMessages">Update messages.txt to the latest version</label>
            <br />
            <button data-bind="jqButton: true, click: createCommit, disable: disableActions">
                Update Version &amp; Create Build Tag
            </button>
        </div>
        <div class="picklog_section">
            <p id="picklog"></p>
        </div>
    </body>
</html>
