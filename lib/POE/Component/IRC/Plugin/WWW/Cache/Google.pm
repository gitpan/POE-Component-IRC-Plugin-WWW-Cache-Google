package POE::Component::IRC::Plugin::WWW::Cache::Google;

use warnings;
use strict;

our $VERSION = '0.0102';

use base 'POE::Component::IRC::Plugin::BasePoCoWrap';
use POE::Component::WWW::Cache::Google;

sub _make_default_args {
    return (
        response_event   => 'irc_google_cache',
        trigger          => qr/^cache\s+(?=\S)/i,
        line_length      => 350,
    );
}

sub _make_poco {
    return POE::Component::WWW::Cache::Google->spawn(
        debug => shift->{debug},
    );
}

sub _make_response_message {
    my $self   = shift;
    my $in_ref = shift;

    delete $in_ref->{content};

    my $out;
    if ( defined $in_ref->{error} ) {
        if ( $in_ref->{error} eq q|Doesn't look like cache exists| ) {
            $out = "No google cache found for $in_ref->{uri}";
        }
        else {
            $out = "Error trying to fetch google cache: $in_ref->{error}";
        }
    }
    else {
        $out = $in_ref->{cache};
    }
    $out = substr $out, 0, $self->{line_length};
    my ($nick) = split /!/, $in_ref->{_who};
    if ( $in_ref->{_type} eq 'public' ) {
        $in_ref->{out} = "$nick, $out";
    }
    else {
        $in_ref->{out} = $out;
    }
    return [ $in_ref->{out} ];
}

sub _make_response_event {
    my $self = shift;
    my $in_ref = shift;

    return {
        ( map { $_ => $in_ref->{$_} }
            qw/out cache/,
        ),
        (
            exists $in_ref->{error} ? ( error => $in_ref->{error} ) : (),
        ),
        map { $_ => $in_ref->{"_$_"} }
            qw/ who channel  message  type  what /,
    }
}

sub _make_poco_call {
    my $self = shift;
    my $data_ref = shift;
    my $uri = $data_ref->{what};
    unless ( $uri =~ m{^(?:ht|f)tps?:://} ) {
        $uri = "http://$uri";
    }
    $self->{poco}->cache( {
            event       => '_poco_done',
            uri         => $uri,
            fetch       => 1,
            max_size    => 100,
            map +( "_$_" => $data_ref->{$_} ),
                keys %$data_ref,
        }
    );
}


1;
__END__

=encoding utf8

=head1 NAME

POE::Component::IRC::Plugin::WWW::Cache::Google - give URIs to Google's cache pages checking if they exist

=head1 SYNOPSIS

    use strict;
    use warnings;

    use POE qw(Component::IRC  Component::IRC::Plugin::WWW::Cache::Google);

    my $irc = POE::Component::IRC->spawn(
        nick        => 'CacheBot',
        server      => 'irc.freenode.net',
        port        => 6667,
        ircname     => 'Google Cache Bot',
        plugin_debug => 1,
    );

    POE::Session->create(
        package_states => [
            main => [ qw(_start irc_001) ],
        ],
    );

    $poe_kernel->run;

    sub _start {
        $irc->yield( register => 'all' );

        $irc->plugin_add(
            'google_cache' =>
                POE::Component::IRC::Plugin::WWW::Cache::Google->new
        );

        $irc->yield( connect => {} );
    }

    sub irc_001 {
        $_[KERNEL]->post( $_[SENDER] => join => '#zofbot' );
    }


    <Zoffix> CacheBot, cache zoffix.com
    <CacheBot> Zoffix, http://www.google.com/search?q=cache:zoffix.com
    <Zoffix> CacheBot, cache non.existsant.com
    <CacheBot> Zoffix, No google cache found for http://non.existsant.com

=head1 DESCRIPTION

This module is a L<POE::Component::IRC> plugin which uses
L<POE::Component::IRC::Plugin> for its base. It provides interface to
see if some URI is present in Google's cache; if it is, plugin will give
the URI pointing to that page.
It accepts input from public channel events, C</notice> messages as well
as C</msg> (private messages); although that can be configured at will.

=head1 CONSTRUCTOR

=head2 C<new>

    # plain and simple
    $irc->plugin_add(
        'google_cache' => POE::Component::IRC::Plugin::WWW::Cache::Google->new
    );

    # juicy flavor
    $irc->plugin_add(
        'google_cache' =>
            POE::Component::IRC::Plugin::WWW::Cache::Google->new(
                line_length      => 350,
                auto             => 1,
                response_event   => 'irc_google_cache',
                banned           => [ qr/aol\.com$/i ],
                addressed        => 1,
                root             => [ qr/mah.net$/i ],
                trigger          => qr/^cache\s+(?=\S)/i,
                triggers         => {
                    public  => qr/^EXAMPLE\s+(?=\S)/i,
                    notice  => qr/^EXAMPLE\s+(?=\S)/i,
                    privmsg => qr/^EXAMPLE\s+(?=\S)/i,
                },
                listen_for_input => [ qw(public notice privmsg) ],
                eat              => 1,
                debug            => 0,
            )
    );

The C<new()> method constructs and returns a new
C<POE::Component::IRC::Plugin::WWW::Cache::Google> object suitable to be
fed to L<POE::Component::IRC>'s C<plugin_add> method. The constructor
takes a few arguments, but I<all of them are optional>. The possible
arguments/values are as follows:

=head3 C<line_length>

    ->new( line_length => 350, );

To prevent really "smart" people from giving the plugin utterly long URIs
and thus spamming the channel you can set the C<line_length> argument
which will cut off the output if it exceeds C<line_length> characters
(this does not include the nick of the person). B<Defaults to:> C<350>

=head3 C<auto>

    ->new( auto => 0 );

B<Optional>. Takes either true or false values, specifies whether or not
the plugin should auto respond to requests. When the C<auto>
argument is set to a true value plugin will respond to the requesting
person with the results automatically. When the C<auto> argument
is set to a false value plugin will not respond and you will have to
listen to the events emited by the plugin to retrieve the results (see
EMITED EVENTS section and C<response_event> argument for details).
B<Defaults to:> C<1>.

=head3 C<response_event>

    ->new( response_event => 'event_name_to_recieve_results' );

B<Optional>. Takes a scalar string specifying the name of the event
to emit when the results of the request are ready. See EMITED EVENTS
section for more information. B<Defaults to:> C<irc_google_cache>

=head3 C<banned>

    ->new( banned => [ qr/aol\.com$/i ] );

B<Optional>. Takes an arrayref of regexes as a value. If the usermask
of the person (or thing) making the request matches any of
the regexes listed in the C<banned> arrayref, plugin will ignore the
request. B<Defaults to:> C<[]> (no bans are set).

=head3 C<root>

    ->new( root => [ qr/\Qjust.me.and.my.friend.net\E$/i ] );

B<Optional>. As opposed to C<banned> argument, the C<root> argument
B<allows> access only to people whose usermasks match B<any> of
the regexen you specify in the arrayref the argument takes as a value.
B<By default:> it is not specified. B<Note:> as opposed to C<banned>
specifying an empty arrayref to C<root> argument will restrict
access to everyone.

=head3 C<trigger>

    ->new( trigger => qr/^cache\s+(?=\S)/i );

B<Optional>. Takes a regex as an argument. Messages matching this
regex, irrelevant of the type of the message, will be considered as requests. See also
B<addressed> option below which is enabled by default as well as
B<trigggers> option which is more specific. B<Note:> the
trigger will be B<removed> from the message, therefore make sure your
trigger doesn't match the actual data that needs to be processed.
B<Defaults to:> C<qr/^cache\s+(?=\S)/i>

=head3 C<triggers>

    ->new( triggers => {
            public  => qr/^EXAMPLE\s+(?=\S)/i,
            notice  => qr/^EXAMPLE\s+(?=\S)/i,
            privmsg => qr/^EXAMPLE\s+(?=\S)/i,
        }
    );

B<Optional>. Takes a hashref as an argument which may contain either
one or all of keys B<public>, B<notice> and B<privmsg> which indicates
the type of messages: channel messages, notices and private messages
respectively. The values of those keys are regexes of the same format and
meaning as for the C<trigger> argument (see above).
Messages matching this
regex will be considered as requests. The difference is that only messages of type corresponding to the key of C<triggers> hashref
are checked for the trigger. B<Note:> the C<trigger> will be matched
irrelevant of the setting in C<triggers>, thus you can have one global and specific "local" triggers. See also
B<addressed> option below which is enabled by default as well as
B<trigggers> option which is more specific. B<Note:> the
trigger will be B<removed> from the message, therefore make sure your
trigger doesn't match the actual data that needs to be processed.
B<By default> not set

=head3 C<addressed>

    ->new( addressed => 1 );

B<Optional>. Takes either true or false values. When set to a true value
all the public messages must be I<addressed to the bot>. In other words,
if your bot's nickname is C<Nick> and your trigger is
C<qr/^trig\s+/>
you would make the request by saying C<Nick, trig EXAMPLE>.
When addressed mode is turned on, the bot's nickname, including any
whitespace and common punctuation character will be removed before
matching the C<trigger> (see above). When C<addressed> argument it set
to a false value, public messages will only have to match C<trigger> regex
in order to make a request. Note: this argument has no effect on
C</notice> and C</msg> requests. B<Defaults to:> C<1>

=head3 C<listen_for_input>

    ->new( listen_for_input => [ qw(public  notice  privmsg) ] );

B<Optional>. Takes an arrayref as a value which can contain any of the
three elements, namely C<public>, C<notice> and C<privmsg> which indicate
which kind of input plugin should respond to. When the arrayref contains
C<public> element, plugin will respond to requests sent from messages
in public channels (see C<addressed> argument above for specifics). When
the arrayref contains C<notice> element plugin will respond to
requests sent to it via C</notice> messages. When the arrayref contains
C<privmsg> element, the plugin will respond to requests sent
to it via C</msg> (private messages). You can specify any of these. In
other words, setting C<( listen_for_input => [ qr(notice privmsg) ] )>
will enable functionality only via C</notice> and C</msg> messages.
B<Defaults to:> C<[ qw(public  notice  privmsg) ]>

=head3 C<eat>

    ->new( eat => 0 );

B<Optional>. If set to a false value plugin will return a
C<PCI_EAT_NONE> after
responding. If eat is set to a true value, plugin will return a
C<PCI_EAT_ALL> after responding. See L<POE::Component::IRC::Plugin>
documentation for more information if you are interested. B<Defaults to>:
C<1>

=head3 C<debug>

    ->new( debug => 1 );

B<Optional>. Takes either a true or false value. When C<debug> argument
is set to a true value some debugging information will be printed out.
When C<debug> argument is set to a false value no debug info will be
printed. B<Defaults to:> C<0>.

=head1 EMITED EVENTS

=head2 C<response_event>

    $VAR1 = {
        'out' => 'Zoffix, http://www.google.com/search?q=cache:www.zoffix.com',
        'what' => 'www.zoffix.com',
        'who' => 'Zoffix!n=Zoffix@unaffiliated/zoffix',
        'type' => 'public',
        'channel' => '#zofbot',
        'message' => 'CacheBot, cache www.zoffix.com',
        'cache' => bless( do{\(my $o = 'http://www.google.com/search?q=cache:www.zoffix.com')}, 'URI::http' )
    };

    $VAR1 = {
        'out' => 'Zoffix, No google cache found for http://non.existant.com',
        'what' => 'non.existant.com',
        'who' => 'Zoffix!n=Zoffix@unaffiliated/zoffix',
        'error' => 'Doesn\'t look like cache exists',
        'type' => 'public',
        'channel' => '#zofbot',
        'message' => 'CacheBot, cache non.existant.com',
        'cache' => bless( do{\(my $o = 'http://www.google.com/search?q=cache:non.existant.com')}, 'URI::http' )
    };

The event handler set up to handle the event, name of which you've
specified in the C<response_event> argument to the constructor
(it defaults to C<irc_google_cache>) will recieve input
every time request is completed. The input will come in C<$_[ARG0]>
on a form of a hashref.
The possible keys/values of that hashrefs are as follows:

=head3 C<cache>

    { 'cache' => bless( do{\(my $o = 'http://www.google.com/search?q=cache:non.existant.com')}, 'URI::http' ) }

The C<cache> key will contain an instance of L<URI> object pointing to
the requested page in Google's cache. Note that this will be the case even
if the plugin was sure the cache doesn't point to the valid page.

=head3 C<error>

    { 'error' => 'Doesn\'t look like cache exists', }

In case of some network error or if the page does not seem to be in google's
cache, the C<error> key will be present and its value will be the error
message.

=head3 C<out>

    { 'out' => 'Zoffix, No google cache found for http://non.existant.com', }

The C<out> key will contain a string of whatever the plugin would normally
spit into the IRC.

=head3 C<who>

    { 'who' => 'Zoffix!Zoffix@i.love.debian.org', }

The C<who> key will contain the user mask of the user who sent the request.

=head3 C<what>

    { 'what' => 'non.existant.com', }

The C<what> key will contain user's message after stripping the C<trigger>
(see CONSTRUCTOR).

=head3 C<message>

    { 'message' => 'CacheBot, cache non.existant.com' }

The C<message> key will contain the actual message which the user sent; that
is before the trigger is stripped.

=head3 C<type>

    { 'type' => 'public', }

The C<type> key will contain the "type" of the message the user have sent.
This will be either C<public>, C<privmsg> or C<notice>.

=head3 C<channel>

    { 'channel' => '#zofbot', }

The C<channel> key will contain the name of the channel where the message
originated. This will only make sense if C<type> key contains C<public>.

=head1 AUTHOR

Zoffix Znet, C<< <zoffix at cpan.org> >>
(L<http://zoffix.com>, L<http://haslayout.net>)

=head1 BUGS

Please report any bugs or feature requests to C<bug-poe-component-irc-plugin-www-cache-google at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=POE-Component-IRC-Plugin-WWW-Cache-Google>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc POE::Component::IRC::Plugin::WWW::Cache::Google

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=POE-Component-IRC-Plugin-WWW-Cache-Google>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/POE-Component-IRC-Plugin-WWW-Cache-Google>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/POE-Component-IRC-Plugin-WWW-Cache-Google>

=item * Search CPAN

L<http://search.cpan.org/dist/POE-Component-IRC-Plugin-WWW-Cache-Google>

=back

=head1 COPYRIGHT & LICENSE

Copyright 2008 Zoffix Znet, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

