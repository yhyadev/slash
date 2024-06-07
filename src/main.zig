const std = @import("std");

const rl = @import("raylib");

const Player = struct {
    position: rl.Vector2,
    size: f32,
    movement_speed: f32,
    dash_scaler: f32,
    health: f32,

    fn init() Player {
        return Player{
            .position = rl.Vector2.zero(),
            .size = 64,
            .movement_speed = 500,
            .dash_scaler = 50,
            .health = 100,
        };
    }

    fn update(self: *Player, enemies: *std.ArrayList(Enemy), dt: f32) !void {
        var velocity = rl.Vector2.zero();

        if (rl.isKeyDown(.key_w)) {
            velocity.y -= 1;
        }

        if (rl.isKeyDown(.key_s)) {
            velocity.y += 1;
        }

        if (rl.isKeyDown(.key_a)) {
            velocity.x -= 1;
        }

        if (rl.isKeyDown(.key_d)) {
            velocity.x += 1;
        }

        velocity = velocity.normalize();
        velocity = velocity.scale(self.movement_speed * dt);

        if (rl.isMouseButtonPressed(.mouse_button_right)) {
            velocity = velocity.scale(self.dash_scaler);
        }

        self.position = self.position.add(velocity);

        var i: usize = 0;
        while (i < enemies.items.len) : (i += 1) {
            if (rl.isMouseButtonPressed(.mouse_button_left)) {
                if (enemies.items[i].position.distance(self.position) < 200) {
                    enemies.items[i].health -= 15;
                }
            }

            if (enemies.items[i].health <= 0) {
                _ = enemies.swapRemove(i);

                self.health += 25;
                self.health = std.math.clamp(self.health, 0, 100);
            }
        }
    }

    fn drawShape(self: Player) void {
        rl.drawRectangleV(self.position, .{ .x = self.size, .y = self.size }, rl.Color.ray_white);
    }

    fn drawUI(self: Player, camera: rl.Camera2D) void {
        rl.drawRectangleV(rl.getWorldToScreen2D(self.position.subtractValue(32), camera), .{ .x = self.health, .y = 15 }, rl.Color.red);
    }
};

const Enemy = struct {
    position: rl.Vector2,
    size: f32,
    health: f32,

    fn init() Enemy {
        const randomX = @as(f32, @floatFromInt(rl.getRandomValue(0, rl.getScreenWidth())));
        const randomY = @as(f32, @floatFromInt(rl.getRandomValue(0, rl.getScreenHeight())));

        const randomVector2 = rl.Vector2.init(randomX, randomY);

        return Enemy{
            .position = randomVector2,
            .size = 64,
            .health = 100,
        };
    }

    fn update(self: *Enemy, player: *Player, dt: f32) void {
        if (self.position.distance(player.position) < 150) {
            player.health -= 0.1;
        }

        self.position = self.position.lerp(player.position, dt);
    }

    fn drawShape(self: Enemy) void {
        rl.drawRectangleV(self.position, .{ .x = self.size, .y = self.size }, rl.Color.red);
    }

    fn drawUI(self: Enemy, camera: rl.Camera2D) void {
        rl.drawRectangleV(rl.getWorldToScreen2D(self.position.subtractValue(32), camera), .{ .x = self.health, .y = 15 }, rl.Color.red);
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());

    const allocator = arena.allocator();

    rl.initWindow(800, 600, "Slash");

    var player = Player.init();

    var enemies = std.ArrayList(Enemy).init(allocator);

    const camera = rl.Camera2D{
        .target = player.position,
        .offset = .{ .x = @as(f32, @floatFromInt(rl.getScreenWidth())) / 2, .y = @as(f32, @floatFromInt(rl.getScreenHeight())) / 2 },
        .rotation = 0,
        .zoom = 0.5,
    };

    var max_enemies: usize = 2;

    var wave_counter: usize = 10;
    var previous_wave_counter: usize = wave_counter;

    while (!rl.windowShouldClose()) {
        if (rl.getRandomValue(0, 500) < 1 and enemies.items.len < max_enemies) {
            try enemies.append(Enemy.init());
        }

        if (enemies.items.len == max_enemies) {
            if (wave_counter == 0) {
                max_enemies += 1;

                wave_counter = previous_wave_counter + 1;
                previous_wave_counter = wave_counter;
            } else {
                wave_counter -= 1;
            }
        }

        const dt = rl.getFrameTime();

        rl.beginDrawing();

        {
            rl.clearBackground(.{ .r = 17, .g = 17, .b = 17, .a = 255 });

            if (player.health <= 0) {
                const game_over_text = "Game Over";
                const game_over_text_font_size = 50;

                const retry_text = "Press Space to Retry";
                const retry_text_font_size = 20;

                const game_over_text_x = @divFloor(rl.getScreenWidth(), 2) - @divFloor(rl.measureText(game_over_text, game_over_text_font_size), 2);

                const retry_text_x = @divFloor(rl.getScreenWidth(), 2) - @divFloor(rl.measureText(retry_text, retry_text_font_size), 2);
                const retry_text_y = rl.getScreenHeight() - rl.measureText(game_over_text, game_over_text_font_size) + 10;

                rl.drawText(game_over_text, game_over_text_x, @divFloor(rl.getScreenHeight(), 2), game_over_text_font_size, rl.Color.ray_white);
                rl.drawText(retry_text, retry_text_x, retry_text_y, retry_text_font_size, rl.Color.ray_white);

                if (rl.isKeyPressed(.key_space)) {
                    player = Player.init();

                    enemies.clearRetainingCapacity();
                }
            } else {
                rl.beginMode2D(camera);

                {
                    try player.update(&enemies, dt);
                    player.drawShape();

                    for (0..enemies.items.len) |i| {
                        enemies.items[i].update(&player, dt);
                        enemies.items[i].drawShape();
                    }
                }

                rl.endMode2D();

                player.drawUI(camera);

                for (0..enemies.items.len) |i| {
                    enemies.items[i].drawUI(camera);
                }
            }
        }

        rl.endDrawing();
    }

    rl.closeWindow();
}
