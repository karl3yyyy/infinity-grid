from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path

import bpy
from mathutils import Vector


REQUIRED_ANIMATIONS = {
    "Idle",
    "Walking_A",
    "1H_Melee_Attack_Slice_Horizontal",
    "2H_Ranged_Shoot",
    "Spellcast_Shoot",
    "Hit_A",
    "Death_A",
}


def parse_args() -> argparse.Namespace:
    arguments = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description="Prepare Infinity Grid CC0 assets")
    parser.add_argument("--project-root", required=True, type=Path)
    return parser.parse_args(arguments)


def reset_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)


def import_gltf(path: Path) -> list[bpy.types.Object]:
    if not path.exists():
        raise FileNotFoundError(path)
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    return [item for item in bpy.data.objects if item not in before]


def remove_object(item: bpy.types.Object) -> None:
    bpy.data.objects.remove(item, do_unlink=True)


def find_armature() -> bpy.types.Object:
    armatures = [item for item in bpy.context.scene.objects if item.type == "ARMATURE"]
    if len(armatures) != 1:
        raise RuntimeError(f"Expected one armature, found {len(armatures)}")
    return armatures[0]


def clean_character(prefix: str, kept_accessories: set[str]) -> bpy.types.Object:
    armature = find_armature()
    for item in list(bpy.context.scene.objects):
        if item == armature:
            continue
        keep_mesh = item.type == "MESH" and (
            item.name.startswith(prefix) or item.name in kept_accessories
        )
        if not keep_mesh:
            remove_object(item)
    return armature


def attach_accessory(
    path: Path,
    armature: bpy.types.Object,
    bone: str,
    location: tuple[float, float, float],
    rotation: tuple[float, float, float] = (0.0, 0.0, 0.0),
    name_prefix: str = "Accessory",
) -> list[bpy.types.Object]:
    imported = import_gltf(path)
    meshes = [item for item in imported if item.type == "MESH"]
    for item in imported:
        if item.type != "MESH":
            remove_object(item)
    for index, mesh in enumerate(meshes):
        mesh.name = f"{name_prefix}_{index + 1}"
        mesh.parent = armature
        mesh.parent_type = "BONE"
        mesh.parent_bone = bone
        mesh.location = location
        mesh.rotation_euler = rotation
        mesh.scale = (1.0, 1.0, 1.0)
    return meshes


def character_height() -> float:
    minimum = float("inf")
    maximum = float("-inf")
    for item in bpy.context.scene.objects:
        if item.type != "MESH":
            continue
        for corner in item.bound_box:
            world = item.matrix_world @ Vector(corner)
            minimum = min(minimum, world.z)
            maximum = max(maximum, world.z)
    return maximum - minimum


def normalize_character(target_height: float = 1.85) -> float:
    height = character_height()
    if height <= 0.01:
        raise RuntimeError("Character has no measurable mesh height")
    scale = target_height / height
    root = bpy.data.objects.new("InfinityGridCharacter", None)
    bpy.context.collection.objects.link(root)
    for item in list(bpy.context.scene.objects):
        if item == root or item.parent is not None:
            continue
        world = item.matrix_world.copy()
        item.parent = root
        item.matrix_world = world
    root.scale = (scale, scale, scale)
    bpy.context.view_layer.objects.active = root
    root.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    root.select_set(False)
    return height


def tint_holy_materials() -> None:
    for material in bpy.data.materials:
        if not material.use_nodes or material.node_tree is None:
            continue
        nodes = material.node_tree.nodes
        links = material.node_tree.links
        principled = next((node for node in nodes if node.type == "BSDF_PRINCIPLED"), None)
        if principled is None:
            continue
        base_input = principled.inputs.get("Base Color")
        if base_input is None or not base_input.is_linked:
            base_input.default_value = (0.72, 0.88, 1.0, 1.0)
            continue
        source_socket = base_input.links[0].from_socket
        links.remove(base_input.links[0])
        hue = nodes.new("ShaderNodeHueSaturation")
        hue.name = "HolyWhiteBlueTint"
        hue.inputs["Hue"].default_value = 0.53
        hue.inputs["Saturation"].default_value = 0.28
        hue.inputs["Value"].default_value = 1.18
        links.new(source_socket, hue.inputs["Color"])
        links.new(hue.outputs["Color"], base_input)
    for item in bpy.context.scene.objects:
        if item.type != "MESH" or not any(word in item.name.lower() for word in ("staff", "wand")):
            continue
        for slot in item.material_slots:
            material = slot.material
            if material and material.use_nodes:
                principled = next(
                    (node for node in material.node_tree.nodes if node.type == "BSDF_PRINCIPLED"),
                    None,
                )
                if principled:
                    principled.inputs["Metallic"].default_value = 0.45
                    principled.inputs["Roughness"].default_value = 0.32


def tint_dark_materials() -> None:
    for material in bpy.data.materials:
        if not material.use_nodes or material.node_tree is None:
            continue
        principled = next(
            (node for node in material.node_tree.nodes if node.type == "BSDF_PRINCIPLED"),
            None,
        )
        if principled is None:
            continue
        base_input = principled.inputs.get("Base Color")
        if base_input and not base_input.is_linked:
            color = base_input.default_value
            base_input.default_value = (
                color[0] * 0.72,
                color[1] * 0.62,
                min(1.0, color[2] * 0.92),
                color[3],
            )


def prune_actions() -> None:
    for item in bpy.context.scene.objects:
        animation_data = item.animation_data
        if animation_data and animation_data.action and animation_data.action.name not in REQUIRED_ANIMATIONS:
            animation_data.action = None
    for action in list(bpy.data.actions):
        if action.name not in REQUIRED_ANIMATIONS:
            bpy.data.actions.remove(action)


def export_glb(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format="GLB",
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_nla_strips=True,
        export_extra_animations=True,
        export_apply=False,
        export_cameras=False,
        export_lights=False,
    )
    if not path.exists() or path.stat().st_size < 1024:
        raise RuntimeError(f"GLB export is missing or too small: {path}")


def process_character(config: dict[str, object], project_root: Path) -> dict[str, object]:
    reset_scene()
    source = project_root / str(config["source"])
    import_gltf(source)
    armature = clean_character(str(config["prefix"]), set(config.get("keep", [])))
    for accessory in config.get("accessories", []):
        attach_accessory(
            project_root / accessory["source"],
            armature,
            accessory["bone"],
            tuple(accessory["location"]),
            tuple(accessory.get("rotation", (0.0, 0.0, 0.0))),
            accessory["name"],
        )
    if config.get("holy"):
        tint_holy_materials()
    if config.get("dark"):
        tint_dark_materials()
    prune_actions()
    source_height = normalize_character()
    output = project_root / str(config["output"])
    export_glb(output)
    actions = sorted(action.name for action in bpy.data.actions)
    missing = sorted(REQUIRED_ANIMATIONS.difference(actions))
    if missing:
        raise RuntimeError(f"{output.name} is missing required animations: {missing}")
    result = {
        "output": output.relative_to(project_root).as_posix(),
        "source": source.relative_to(project_root).as_posix(),
        "size": output.stat().st_size,
        "source_height": round(source_height, 4),
        "mesh_count": sum(1 for item in bpy.context.scene.objects if item.type == "MESH"),
        "animations": actions,
    }
    print("CHARACTER_OK", json.dumps(result, ensure_ascii=False))
    return result


def process_environment(source: Path, output: Path) -> dict[str, object]:
    reset_scene()
    import_gltf(source)
    for item in list(bpy.context.scene.objects):
        if item.type in {"CAMERA", "LIGHT"}:
            remove_object(item)
    export_glb(output)
    result = {"output": output.name, "source": source.name, "size": output.stat().st_size}
    print("ENVIRONMENT_OK", json.dumps(result))
    return result


def main() -> None:
    args = parse_args()
    root = args.project_root.resolve()
    adventurers = Path(
        "assets/source_assets/kaykit_adventurers/"
        "KayKit-Character-Pack-Adventures-1.0-main/addons/"
        "kaykit_character_pack_adventures"
    )
    skeletons = Path(
        "assets/source_assets/kaykit_skeletons/"
        "KayKit-Character-Pack-Skeletons-1.0-main/addons/"
        "kaykit_character_pack_skeletons"
    )
    weapons = Path(
        "assets/source_assets/kaykit_fantasy_weapons_bits/"
        "KayKit_FantasyWeaponsBits_1.0_FREE/Assets/gltf"
    )
    characters = [
        {
            "source": adventurers / "Characters/gltf/Knight.glb",
            "output": "assets/characters/player/player_swordsman.glb",
            "prefix": "Knight_",
            "keep": ["1H_Sword", "Round_Shield"],
        },
        {
            "source": adventurers / "Characters/gltf/Rogue_Hooded.glb",
            "output": "assets/characters/player/player_archer.glb",
            "prefix": "Rogue_",
            "accessories": [
                {"source": weapons / "bow_B_withString.gltf", "bone": "handslot.r", "location": (-0.105, -0.122, 0.0), "name": "Longbow"},
                {"source": adventurers / "Assets/gltf/quiver.gltf", "bone": "chest", "location": (0.0, 0.08, -0.19), "name": "Quiver"},
            ],
        },
        {
            "source": adventurers / "Characters/gltf/Mage.glb",
            "output": "assets/characters/player/player_priest.glb",
            "prefix": "Mage_",
            "keep": ["2H_Staff", "Spellbook"],
            "holy": True,
        },
        {
            "source": skeletons / "Characters/gltf/Skeleton_Warrior.glb",
            "output": "assets/characters/enemy/enemy_swordsman.glb",
            "prefix": "Skeleton_Warrior_",
            "dark": True,
            "accessories": [
                {"source": skeletons / "Assets/gltf/Skeleton_Blade.gltf", "bone": "handslot.r", "location": (0.0, -0.079, 0.0), "name": "BoneBlade"},
                {"source": skeletons / "Assets/gltf/Skeleton_Shield_Small_A.gltf", "bone": "handslot.l", "location": (0.0, -0.095, 0.156), "name": "BoneShield"},
            ],
        },
        {
            "source": skeletons / "Characters/gltf/Skeleton_Rogue.glb",
            "output": "assets/characters/enemy/enemy_archer.glb",
            "prefix": "Skeleton_Rogue_",
            "dark": True,
            "accessories": [
                {"source": weapons / "bow_A_withString.gltf", "bone": "handslot.r", "location": (-0.105, -0.122, 0.0), "name": "DarkLongbow"},
                {"source": skeletons / "Assets/gltf/Skeleton_Quiver.gltf", "bone": "chest", "location": (0.0, 0.08, -0.19), "name": "BoneQuiver"},
            ],
        },
        {
            "source": skeletons / "Characters/gltf/Skeleton_Mage.glb",
            "output": "assets/characters/enemy/enemy_priest.glb",
            "prefix": "Skeleton_Mage_",
            "dark": True,
            "accessories": [
                {"source": skeletons / "Assets/gltf/Skeleton_Staff.gltf", "bone": "handslot.r", "location": (0.0, -0.079, 0.0), "name": "DarkStaff"},
            ],
        },
    ]
    character_results = [process_character(config, root) for config in characters]

    dungeon = root / (
        "assets/source_assets/kaykit_dungeon_remastered/"
        "KayKit-Dungeon-Remastered-1.0-main/addons/"
        "kaykit_dungeon_remastered/Assets/gltf"
    )
    nature = root / "assets/source_assets/kenney_nature_kit/Models/GLTF format"
    environment_sources = [
        (dungeon / "wall.gltf.glb", root / "assets/environment/dungeon_wall.glb"),
        (dungeon / "wall_pillar.gltf.glb", root / "assets/environment/dungeon_pillar.glb"),
        (dungeon / "box_small.gltf.glb", root / "assets/environment/dungeon_crate.glb"),
        (nature / "tree_oak.glb", root / "assets/environment/nature_tree.glb"),
        (nature / "rock_largeA.glb", root / "assets/environment/nature_rock.glb"),
        (nature / "plant_bushDetailed.glb", root / "assets/environment/nature_bush.glb"),
    ]
    environment_results = [process_environment(source, output) for source, output in environment_sources]

    sky_source = root / "assets/source_assets/poly_haven_cloud_layers/cloud_layers_2k.hdr"
    sky_output = root / "assets/sky/cloud_layers_2k.hdr"
    sky_output.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(sky_source, sky_output)
    manifest = {
        "blender": bpy.app.version_string,
        "characters": character_results,
        "environment": environment_results,
        "sky": {"source": sky_source.relative_to(root).as_posix(), "output": sky_output.relative_to(root).as_posix()},
    }
    manifest_path = root / "assets/processed_asset_manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False), encoding="utf-8")
    print("PIPELINE_OK", manifest_path)


if __name__ == "__main__":
    main()
