use Mojo::Base -strict;

BEGIN { $ENV{MOJO_REACTOR} = 'Mojo::Reactor::Poll' }

use Test::More;

plan skip_all => 'set TEST_ONLINE to enable this test'
  unless $ENV{TEST_ONLINE};

use Mojo::Pg;
use Mojolicious::Lite;
use Test::Mojo;

helper pg => sub { state $pg = Mojo::Pg->new($ENV{TEST_ONLINE}) };

app->pg->migrations->name('app_test')->from_data->migrate;

get '/blocking' => sub {
  my $c = shift;
  $c->render(
    text => $c->pg->db->query('select * from app_test')->hash->{stuff});
};

get '/non-blocking' => sub {
  my $c = shift;
  $c->pg->db->query(
    'select * from app_test' => sub {
      my ($db, $err, $results) = @_;
      $c->render(text => $results->hash->{stuff});
    }
  );
};

# Make sure database connections are idle for a bit
my $t = Test::Mojo->new;
$t->ua->max_connections(0);

# Make sure migrations are not served as static files
$t->get_ok('/app_test')->status_is(404);

# Blocking select (twice to allow connection reuse)
$t->get_ok('/blocking')->status_is(200)->content_is('I ♥ Mojolicious!');
$t->get_ok('/blocking')->status_is(200)->content_is('I ♥ Mojolicious!');

# Non-blocking select (twice to allow connection reuse)
$t->get_ok('/non-blocking')->status_is(200)->content_is('I ♥ Mojolicious!');
$t->get_ok('/non-blocking')->status_is(200)->content_is('I ♥ Mojolicious!');
$t->app->pg->migrations->migrate(0);

done_testing();

__DATA__
@@ app_test
-- 1 up
create table if not exists app_test (stuff varchar(255));

-- 2 up
insert into app_test values ('I ♥ Mojolicious!');

-- 1 down
drop table app_test;
