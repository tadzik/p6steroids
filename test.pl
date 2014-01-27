use v6;
use NativeCall;

constant PATH = './sdlwrapper';
constant SDLK_SPACE = 32;
constant SDLK_UP    = 273;
constant SDLK_DOWN  = 274;
constant SDLK_RIGHT = 275;
constant SDLK_LEFT  = 276;

constant WIDTH = 1680;
constant HEIGHT = 1050;

sub game_init(int, int)                 returns OpaquePointer is native(PATH) { * }
sub game_set_keypressed_cb(OpaquePointer, &cb(int))           is native(PATH) { * }
sub game_get_surface(OpaquePointer)     returns OpaquePointer is native(PATH) { * }
sub game_is_pressed(OpaquePointer, int) returns int           is native(PATH) { * }
sub game_is_running(OpaquePointer)      returns int           is native(PATH) { * }
sub game_wait(OpaquePointer)                                  is native(PATH) { * }
sub game_free(OpaquePointer)                                  is native(PATH) { * }
sub game_fill_screen(OpaquePointer, int, int, int)            is native(PATH) { * }
sub game_draw_filled_ellipse(OpaquePointer, int, int, int, int,
                                     int, int, int, int)      is native(PATH) { * }
sub game_draw_ellipse(OpaquePointer, int, int, int, int,
                                     int, int, int, int)      is native(PATH) { * }
sub game_draw_triangle(OpaquePointer, int, int,
                                      int, int,
                                      int, int,
                                      int, int, int, int)     is native(PATH) { * }
sub game_flip(OpaquePointer)                                  is native(PATH) { * }

class Game;

role Drawable {
    method draw(Game $g) { !!! }
}

class Game {
    has $.x;
    has $.y;
    has &.on_keypressed = sub ($k) { };
    has Mu $!game;
    
    submethod BUILD(:$!x, :$!y, :&!on_keypressed) {
        $!game := game_init($!x, $!y);
        sub key_cb(int $k) {
            &!on_keypressed($k)
        }
        game_set_keypressed_cb($!game, &key_cb);
    }

    method is_pressed(int $key) {
        game_is_pressed($!game, $key);
    }

    method is_running { game_is_running($!game) }
    method wait       { game_wait($!game)       }
    method free       { game_free($!game)       }

    method draw_filled_ellipse(int $x, int $y, int $rx, int $ry, int $r, int $g, int $b, int $a) {
        game_draw_filled_ellipse($!game, $x, $y, $rx, $ry, $r, $g, $b, $a)
    }

    method draw_ellipse(int $x, int $y, int $rx, int $ry, int $r, int $g, int $b, int $a) {
        game_draw_ellipse($!game, $x, $y, $rx, $ry, $r, $g, $b, $a)
    }

    method draw_triangle(int $x1, int $y1, int $x2, int $y2, int $x3, int $y3,
                         int $r, int $g, int $b, int $a) {
        game_draw_triangle($!game, $x1, $y1, $x2, $y2, $x3, $y3, $r, $g, $b, $a)
    }

    method draw(*@drawables) {
        game_fill_screen($!game, 0, 0, 0);
        for @drawables {
            $_.draw(self)
        }
        game_flip($!game);
    }
}

macro rad($deg) { quasi { {{{ $deg }}} * pi / 180 } }

class Asteroid {
    has Int $.x;
    has Int $.y;
    has Int $.vel;
    has Int $.rot;
    has Int $.size;
    has Bool $.alive is rw = True;

    method draw(Game $g) {
        $g.draw_ellipse($!x, $!y, $!size, $!size, 255, 255, 255, 255);
    }

    method move {
        $!x += Int(cos(rad($!rot)) * $!vel);
        $!y += Int(sin(rad($!rot)) * $!vel);
        $!x %= WIDTH;
        $!y %= HEIGHT;
        if ($!x < 0) { $!x += WIDTH  }
        if ($!y < 0) { $!y += HEIGHT }
    }

    method split {
        $!size = Int($!size / 2);
        if $!size < 20 {
            False
        } else {
            my $diff = (0..50).pick + 10;
            $!rot += $diff;
            Asteroid.new(
                :$!x, :$!y, :$!vel, :$!size, :rot($!rot - 2*$diff)
            )
        }
    }

    method is_inside($x, $y) {
        sqrt(($x - $!x) ** 2 + ($y - $!y) ** 2) < $!size
    }
}

class Bullet does Drawable {
    has Int $.x;
    has Int $.y;
    has Int $.vel;
    has Int $.rot;
    has Int $.age is rw;

    method move {
        $!x += Int(cos(rad($!rot)) * $!vel);
        $!y += Int(sin(rad($!rot)) * $!vel);
        $!x %= WIDTH;
        $!y %= HEIGHT;
        if ($!x < 0) { $!x += WIDTH  }
        if ($!y < 0) { $!y += HEIGHT }
        $!age++;
    }

    method alive {
        $!age < 50
    }

    method draw(Game $g) {
        $g.draw_filled_ellipse($!x, $!y, 2, 2, 255, 255, 255, 255)
    }

    method hits_asteroid(Asteroid $a) {
        $a.is_inside($!x, $!y)
    }
}

class Spaceship does Drawable {
    has Int $.x;
    has Int $.y;
    has Int $.size;
    has Int $.rot is rw = 0;
    has Num $.vel is rw = Num(0);

    # vertices
    has Int $.x1;
    has Int $.x2;
    has Int $.x3;
    has Int $.y1;
    has Int $.y2;
    has Int $.y3;

    method move {
        $!x += Int(cos(rad($!rot)) * $!vel.floor);
        $!y += Int(sin(rad($!rot)) * $!vel.floor);
        $!x %= WIDTH;
        $!y %= HEIGHT;
        if $!x < 0 {
            $!x += WIDTH
        }
        if $!y < 0 {
            $!y += HEIGHT
        }
        if $!vel > 0 {
            $!vel -= 0.04
        } elsif $!vel < 0 {
            $!vel += 0.04
        }

        $!x1 = $!x + Int(cos(rad($!rot))             * $!size    );
        $!y1 = $!y + Int(sin(rad($!rot))             * $!size    );
        $!x2 = $!x + Int(cos(rad($!rot + 120 % 360)) * $!size / 2);
        $!y2 = $!y + Int(sin(rad($!rot + 120 % 360)) * $!size / 2);
        $!x3 = $!x + Int(cos(rad($!rot + 240 % 360)) * $!size / 2);
        $!y3 = $!y + Int(sin(rad($!rot + 240 % 360)) * $!size / 2);
    }

    method draw(Game $g) {
        $g.draw_triangle($!x1, $!y1,
                         $!x2, $!y2,
                         $!x3, $!y3,
                         255, 255, 255, 255)
    }

    method fire {
        Bullet.new(
            x => Int($!x + cos(rad($!rot)) * $!size),
            y => Int($!y + sin(rad($!rot)) * $!size),
            vel => Int($!vel + 10),
            rot => $!rot,
            age => 0,
        )
    }

    method hits_asteroid(Asteroid $a) {
        so any ($a.is_inside($!x1, $!y1), $a.is_inside($!x2, $!y2), $a.is_inside($!x3, $!y3))
    }
}

my $player = Spaceship.new(x => 40, y => 300, size => 40);
my @projectiles;
my @asteroids;
for ^4 {
    @asteroids.push: Asteroid.new(
        :size(80), :vel(5), :rot((^360).pick), :x((^WIDTH).pick), :y((^HEIGHT).pick),
    )
}
my $game = Game.new(:x(WIDTH), :y(HEIGHT),
                    on_keypressed => sub ($key) {
    if $key == SDLK_SPACE {
        @projectiles.push: $player.fire
    }
});
my $time = nqp::time_n;
my $iters = 0;
my $lost = False;
while !$lost and $game.is_running {
    $game.wait;

    my @np;
    my @na;
    for @projectiles -> $p {
        $p.move;
        for @asteroids -> $a {
            if $p.hits_asteroid($a) {
                $p.age = 9999; # die
                my $ast = $a.split;
                if $ast {
                    @na.push: $ast;
                } else {
                    $a.alive = False;
                }
            }
        }
        if $p.alive {
            @np.push: $p
        }
    }
    @asteroids.=grep(*.alive);
    @asteroids.push: @na;
    @projectiles = @np;

    if $game.is_pressed(SDLK_UP) {
        if $player.vel < 10 { $player.vel++ }
    }
    if $game.is_pressed(SDLK_DOWN) {
        if $player.vel > -10 { $player.vel-- }
    }
    if $game.is_pressed(SDLK_LEFT) {
        $player.rot -= 10
    }
    if $game.is_pressed(SDLK_RIGHT) {
        $player.rot += 10
    }
    if $game.is_pressed(SDLK_RIGHT) {
        $player.rot += 10
    }
    $player.rot %= 360;
    $player.move;
    @asteroids».move;
    for @asteroids -> $a {
        if $player.hits_asteroid($a) {
            say "FAIL";
            $lost = True;
            last;
        }
    }
    $game.draw($player, @projectiles, @asteroids);

    $iters++;
}
my $elapsed = nqp::time_n() - $time;
say "$iters iterations in $elapsed seconds, giving {$iters / $elapsed} fps, sort of";
$game.free;
