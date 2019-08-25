-- stop the player's character colliding with itself
-- necessary to allow "run there" character pathfinding to start from current character position
-- further reading:
--   https://wiki.factorio.com/Prototype/Entity#collision_mask
--   https://lua-api.factorio.com/latest/LuaEntityPrototype.html#LuaEntityPrototype.collision_mask_collides_with_self
--   https://forums.factorio.com/viewtopic.php?t=51672
--   https://wiki.factorio.com/Types/CollisionMask#.22not-colliding-with-itself.22
data.raw.character["character"].collision_mask = {
    "player-layer", "train-layer", "consider-tile-transitions", "not-colliding-with-itself",
}
