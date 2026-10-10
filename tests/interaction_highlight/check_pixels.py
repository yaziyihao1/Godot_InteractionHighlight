"""Read actual GPU screenshots + RGBA16F/R32F readbacks; never accepts empty readiness.

Usage: python tests/interaction_highlight/check_pixels.py <absolute-output-directory>
The independent white/black geometry oracle defines complete and visible coverage.
Reports numeric failures and saves pixel-difference evidence, with exit 1 on failure.
"""
import argparse
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw


def rgb(path):
    return np.asarray(Image.open(path).convert("RGB"), dtype=np.int16)


def shifted(mask, dx, dy):
    result = np.zeros_like(mask)
    h, w = mask.shape
    x0, x1 = max(0, dx), min(w, w + dx)
    y0, y1 = max(0, dy), min(h, h + dy)
    if x1 > x0 and y1 > y0:
        result[y0:y1, x0:x1] = mask[y0-dy:y1-dy, x0-dx:x1-dx]
    return result


def dilate(mask, radius):
    result = mask.copy()
    limit = math.ceil(radius)
    for dy in range(-limit, limit + 1):
        for dx in range(-limit, limit + 1):
            if dx * dx + dy * dy <= radius * radius:
                result |= shifted(mask, dx, dy)
    return result


def expected_line(complete, visible, width=2.0, target_metres=None, destination_metres=None):
    result = np.zeros(complete.shape, dtype=np.float32)
    limit = math.ceil(width + 0.5)
    for dy in range(-limit, limit + 1):
        for dx in range(-limit, limit + 1):
            value = min(1.0, max(0.0, width + 0.5 - math.hypot(dx, dy)))
            if value > 0:
                eligible = shifted(visible, dx, dy)
                if target_metres is not None and destination_metres is not None:
                    eligible &= shifted(target_metres, dx, dy) <= destination_metres + 0.002
                np.maximum(result, eligible * value, out=result)
    result[complete] = 0
    return result


def independent_floor_depth(record, depth):
    """Ray/plane intersection is independent of the addon and GPU scene-depth buffer.

    A floor in front of an outer-outline destination correctly rejects that pixel,
    even when every pixel of the target itself is visible. This is not a gap.
    """
    oracle = record.get("camera_oracle")
    if not oracle or "near" not in oracle or depth is None:
        return None, None
    h, w = depth.shape[:2]
    origin = np.asarray(oracle["origin"])
    forward = np.asarray(oracle["forward"])
    corners = np.asarray(oracle["depth1_corner_world"])
    u = ((np.arange(w) + 0.5) / w)[None, :, None]
    v = ((np.arange(h) + 0.5) / h)[:, None, None]
    rays = corners[0] - origin + u * (corners[1] - corners[0]) + v * (corners[2] - corners[0])
    with np.errstate(divide="ignore", invalid="ignore"):
        t = (oracle["ground_y"] - origin[1]) / rays[..., 1]
        floor_metres = t * np.einsum("ijk,k->ij", rays, forward)
    floor_metres[t <= 0] = np.inf
    z = depth[..., 0]
    # Camera3D.get_camera_projection is the API projection, before Godot applies
    # the Vulkan reverse-Z correction. Use the independent near/far relation.
    near, far = oracle["near"], oracle["far"]
    with np.errstate(divide="ignore", invalid="ignore"):
        target_metres = near * far / (near + z * (far - near))
    target_metres[z <= 0] = np.inf
    return target_metres, floor_metres


def read_texture(record, kind="coverage"):
    item = record.get(kind, {})
    w, h = item.get("size", [0, 0])
    channels = 4 if kind == "coverage" else 1
    dtype = "<f2" if channels == 4 else "<f4"
    if w <= 0 or h <= 0 or item.get("error") or not item.get("path"):
        return None
    raw = np.fromfile(item["path"], dtype=dtype)
    if raw.size != w * h * channels:
        return None
    return raw.reshape(h, w, channels).astype(np.float32)


def make_review_crops(directory, groups):
    """Copy actual screenshot pixels; nearest-neighbor zoom never resynthesizes them."""
    output = directory / "evidence"
    output.mkdir(exist_ok=True)
    specifications = [("handle_hole", "type_handle", "whole", 4),
                      ("rigid_seams", "type_rigid", "whole", 4),
                      ("partial_wall", "occlusion_partial", "whole", 4),
                      ("edge_1920", "resolution_1920x1080", "edge", 8),
                      ("edge_2560", "resolution_2560x1440", "edge", 8)]
    records = []
    for label, case, focus, zoom in specifications:
        if case == "type_handle" and case not in groups and "smoke_handle" in groups:
            case = "smoke_handle"
        phases = groups.get(case)
        if phases is None:
            continue
        mask = rgb(phases["projection"]["path"]).max(axis=2) > 127
        ys, xs = np.nonzero(mask)
        if not xs.size:
            continue
        x0, x1, y0, y1 = int(xs.min()), int(xs.max()) + 1, int(ys.min()), int(ys.max()) + 1
        if focus == "edge":
            # Top/right exterior corner: contains normal art, white outline and glow.
            edge_y = int(ys[xs == xs.max()].min())
            x0, y0 = max(x0, x1 - 40), max(y0, edge_y - 8)
            y1 = min(y1, y0 + 40)
        h, w = mask.shape
        box = (max(0, x0 - 12), max(0, y0 - 12), min(w, x1 + 12), min(h, y1 + 12))
        for phase in ["off", "outline", "fill"]:
            source = Path(phases[phase]["path"])
            original = Image.open(source).convert("RGB")
            crop = original.crop(box)
            actual_path = output / f"{label}_{phase}_actual.png"
            zoom_path = output / f"{label}_{phase}_nearest_{zoom}x.png"
            crop.save(actual_path)
            enlarged = crop.resize((crop.width * zoom, crop.height * zoom), Image.Resampling.NEAREST)
            annotated = Image.new("RGB", (enlarged.width, enlarged.height + 24), "#202020")
            annotated.paste(enlarged, (0, 24))
            ImageDraw.Draw(annotated).text((5, 5), f"{label} | {phase} | {zoom}x NEAREST | actual screenshot crop", fill="white")
            annotated.save(zoom_path)
            records.append({"case": case, "phase": phase, "source": str(source), "crop_box": list(box), "actual": str(actual_path), "nearest_zoom": str(zoom_path), "zoom": zoom, "resampling": "NEAREST", "annotation_header_pixels": 24})
    (output / "crop_manifest.json").write_text(json.dumps(records, ensure_ascii=False, indent=2), encoding="utf-8")
    return records


def check_case(name, phases, evidence):
    failures = []
    metrics = {"case": name, "failures": failures}
    off = rgb(phases["off"]["path"])
    outline = rgb(phases["outline"]["path"])
    fill = rgb(phases["fill"]["path"])
    complete = rgb(phases["projection"]["path"]).max(axis=2) > 127
    visible = rgb(phases["visible"]["path"]).max(axis=2) > 127
    metrics["projection_pixels"] = int(complete.sum())
    metrics["visible_pixels"] = int(visible.sum())
    metrics["screen_size"] = [off.shape[1], off.shape[0]]
    if name.startswith("resolution_"):
        requested = [int(value) for value in name.removeprefix("resolution_").split("x")]
        if metrics["screen_size"] != requested:
            failures.append(f"Requested screenshot {requested} but actual size is {metrics['screen_size']}")
    if not complete.any():
        failures.append("Independent target projection is empty: invalid camera/test setup")
    outside = ~complete
    band = dilate(visible, 5.5) & outside
    # One-pixel raster guard around independent geometry, never a whole-screen mask.
    outline_allowed = dilate(band, 1.0)
    fill_allowed = outline_allowed | dilate(visible, 1.0)
    for phase, picture, allowed in [("outline", outline, outline_allowed), ("fill", fill, fill_allowed)]:
        delta = np.abs(picture - off).max(axis=2)
        outside_max = int(delta[~allowed].max(initial=0))
        outside_count = int(((delta > 1) & ~allowed).sum())
        metrics[f"{phase}_outside_max_255"] = outside_max
        metrics[f"{phase}_outside_changed_pixels"] = outside_count
        metrics[f"{phase}_changed_pixels"] = int((delta > 1).sum())
        if outside_max > 1:
            failures.append(f"{phase}: {outside_count} pixels outside bands changed >1/255 (max={outside_max})")
        heat = np.zeros_like(picture, dtype=np.uint8)
        heat[..., 0] = np.clip(delta * 4, 0, 255)
        heat[(delta > 1) & ~allowed] = [255, 0, 255]
        Image.fromarray(heat).save(evidence / f"{name}_{phase}_difference.png")
    o = read_texture(phases["outline"])
    f = read_texture(phases["fill"])
    for phase in ["outline", "fill"]:
        state = phases[phase]["debug"]
        metrics[f"{phase}_data_ready"] = state.get("ready")
        metrics[f"{phase}_overlay_ready"] = state.get("overlay_ready")
        if not state.get("ready") or state.get("coverage_count", 0) < 1 or state.get("error") or state.get("support_error") or state.get("transient_error"):
            failures.append(f"{phase}: renderer not ready/supported: {state}")
        if visible.any() and state.get("overlay_ready") is not True:
            failures.append(f"{phase}: stable visible target has no actual overlay readiness")
    if o is None or f is None:
        failures.append("Missing/empty RGBA16F readback")
        return metrics
    metrics["rd_size"] = [o.shape[1], o.shape[0]]
    if o.shape[:2] != complete.shape or f.shape != o.shape:
        failures.append("RD dimensions differ from screenshot: actual output pixel width unverified")
        return metrics
    if not np.isfinite(o).all() or not np.isfinite(f).all():
        failures.append("Nonfinite GPU coverage values")
    mode_diff = float(np.abs(o[..., [0, 2]] - f[..., [0, 2]]).max(initial=0))
    metrics["mode2_outline_glow_max_difference"] = mode_diff
    if mode_diff > 1 / 255:
        failures.append("Mode2 outline/glow differs from mode1")
    outer_mode_diff = int(np.abs(outline - fill)[~dilate(complete, 1.0)].max(initial=0))
    metrics["mode2_outer_screenshot_max_difference_255"] = outer_mode_diff
    if outer_mode_diff > 1:
        failures.append("Mode2 outer outline screenshot differs from mode1 >1/255")
    depth = read_texture(phases["outline"], "depth")
    if "depth" in phases["outline"]:
        if depth is None or depth.shape[:2] != complete.shape or not np.isfinite(depth).all():
            failures.append("Invalid R32F target depth readback")
        else:
            positive = depth[..., 0][depth[..., 0] > 0]
            metrics["r32f_positive_pixels"] = int(positive.size)
            metrics["r32f_positive_depth_min"] = float(positive.min(initial=1))
            metrics["r32f_positive_depth_max"] = float(positive.max(initial=0))
            if not positive.size or np.any(positive > 1):
                failures.append("Target R32F lacks valid reverse-Z depth")
    projection = o[..., 3] > 0.5
    gpu_visible = o[..., 1] > 0.5
    projection_error = (projection & ~dilate(complete, 1.0)) | (complete & ~dilate(projection, 1.0))
    visibility_error = (gpu_visible & ~dilate(visible, 1.0)) | (visible & ~dilate(gpu_visible, 1.0))
    metrics["projection_mismatch_pixels_beyond_1px"] = int(projection_error.sum())
    metrics["visibility_mismatch_pixels_beyond_1px"] = int(visibility_error.sum())
    metrics["internal_projection_outline_pixels"] = int(((o[..., 0] > 1 / 255) & projection).sum())
    if projection_error.any() or visibility_error.any():
        failures.append("GPU complete/visible coverage disagrees with independent raster oracle")
    if metrics["internal_projection_outline_pixels"]:
        failures.append("Outline crosses complete projection: internal occlusion-cut edges")
    if "wall" in phases:
        wall = rgb(phases["wall"]["path"]).max(axis=2) > 127
        wall_interior = ~dilate(~wall, 1.0)
        leaks = ((o[..., :3].max(axis=2) > 1 / 255) & wall_interior)
        metrics["occluder_destination_leak_pixels"] = int(leaks.sum())
        if leaks.any():
            failures.append("Outline/glow/fill leaks onto a visible foreground wall")
    if "live" in phases:
        live_delta = int(np.abs(rgb(phases["live"]["path"]) - fill).max(initial=0))
        metrics["live_switch_or_rebind_max_delta_255"] = live_delta
        if live_delta > 1:
            failures.append("Live target switch/camera rebind differs from fresh target result")
        if name == "target_burst_switched":
            burst = phases["live"].get("burst", {})
            metrics["burst"] = burst
            if burst.get("start_frame") != burst.get("end_frame") or burst.get("operation_count", 0) < 8 or burst.get("final_target_id") != phases["live"]["debug"].get("target_id"):
                failures.append("Burst lacks same-frame operations or the final target ID is wrong")
    if "burst_frame_1" in phases:
        first = rgb(phases["burst_frame_1"]["path"])
        first_delta = np.abs(first - off).max(axis=2)
        metrics["burst_first_frame_outside_max_255"] = int(first_delta[~fill_allowed].max(initial=0))
        metrics["burst_first_frame_overlay_ready"] = phases["burst_frame_1"]["debug"].get("overlay_ready")
        metrics["burst_first_frame_suppressed"] = metrics["burst_first_frame_overlay_ready"] is False
        if metrics["burst_first_frame_outside_max_255"] > 1:
            failures.append("Same-frame burst leaves stale highlight outside final target bands")
    transforms = [np.asarray(phases[phase].get("target_transform", [])) for phase in ["off", "outline", "fill", "projection", "visible"]]
    if all(transform.shape == (4, 3) for transform in transforms):
        metrics["geometry_oracle_transform_max_difference"] = max(float(np.abs(transform - transforms[0]).max()) for transform in transforms)
        if metrics["geometry_oracle_transform_max_difference"] > 1e-6:
            failures.append("Geometry oracle did not retain the actual target transform")
        if name == "target_root_rotated" and np.abs(transforms[0][:3] - np.eye(3)).max() < 0.05:
            failures.append("Root rotation case has no actual rotation")
        if name == "target_root_nonuniform_scaled":
            scales = np.linalg.norm(transforms[0][:3], axis=1)
            metrics["actual_root_scale"] = scales.tolist()
            if scales.max() - scales.min() < 0.1:
                failures.append("Root nonuniform scale case has no actual nonuniform scale")
    elif name in ["target_root_rotated", "target_root_nonuniform_scaled"]:
        failures.append("Missing transform metadata for new root-transform evidence")
    if not visible.any():
        metrics["fully_occluded_max_rgb_coverage"] = float(o[..., :3].max(initial=0))
        if o[..., :3].max(initial=0) > 1 / 255:
            failures.append("Fully occluded target leaks GPU coverage")
    else:
        if not (np.abs(outline - off) > 1).any():
            failures.append("Nonempty visible target produces no visible outline")
        if not (np.abs(fill - outline) > 1).any():
            failures.append("Mode2 produces no visible fill")
    # Exact pixel-radius envelope is checked only for unobstructed silhouettes.
    # Occluded destination pixels are correctly depth-rejected by the GPU.
    if np.array_equal(complete, visible) and complete.any():
        target_metres, floor_metres = independent_floor_depth(phases["outline"], depth)
        raw_expected = expected_line(projection, gpu_visible)
        expected = expected_line(projection, gpu_visible, target_metres=target_metres, destination_metres=floor_metres)
        metrics["floor_depth_rejected_outer_pixels"] = int(((raw_expected - expected) > 1 / 255).sum())
        width_error = np.abs(o[..., 0] - expected)
        metrics["width_envelope_max_error"] = float(width_error.max(initial=0))
        metrics["width_envelope_error_pixels"] = int((width_error > 1 / 255).sum())
        metrics["continuous_outer_band_pixels"] = int((expected > 1 / 255).sum())
        if metrics["width_envelope_error_pixels"]:
            failures.append("2px outline envelope has gaps or incorrect actual pixel width")
    return metrics


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("directory", type=Path)
    args = parser.parse_args()
    manifest = json.loads((args.directory / "manifest.json").read_text(encoding="utf-8-sig"))
    evidence = args.directory / "pixel_evidence"
    evidence.mkdir(exist_ok=True)
    groups = {}
    for record in manifest["captures"]:
        groups.setdefault(record["case"], {})[record["phase"]] = record
    report = {"adapter": manifest["adapter"], "headless": manifest["headless"], "cases": [], "failures": []}
    for name, phases in groups.items():
        if all(phase in phases for phase in ["off", "outline", "fill", "projection", "visible"]):
            result = check_case(name, phases, evidence)
            report["cases"].append(result)
            report["failures"].extend(f"{name}: {failure}" for failure in result["failures"])
    transient_results = []
    for name, phases in groups.items():
        for phase, record in phases.items():
            if not phase.startswith("resize_frame_"):
                continue
            picture = rgb(record["path"])
            reference = phases
            if picture.shape != rgb(phases["off"]["path"]).shape:
                reference = next((candidate for case, candidate in groups.items()
                    if case.startswith("resolution_") and "off" in candidate
                    and rgb(candidate["off"]["path"]).shape == picture.shape), None)
            result = {"case": name, "phase": phase, "frame_drawn": record.get("frame_drawn"), "ready": record["debug"].get("ready"), "data_ready": record["debug"].get("ready"), "overlay_ready": record["debug"].get("overlay_ready"), "screen_size": [picture.shape[1], picture.shape[0]]}
            result["suppressed"] = result["overlay_ready"] is False
            if reference is None:
                result["failure"] = "No same-size off/geometry oracle for transient"
                report["failures"].append(f"{name}/{phase}: {result['failure']}")
            else:
                visible = rgb(reference["visible"]["path"]).max(axis=2) > 127
                complete = rgb(reference["projection"]["path"]).max(axis=2) > 127
                allowed = dilate((dilate(visible, 5.5) & ~complete), 1.0) | dilate(visible, 1.0)
                delta = np.abs(picture - rgb(reference["off"]["path"])).max(axis=2)
                result["outside_max_255"] = int(delta[~allowed].max(initial=0))
                result["outside_changed_pixels"] = int(((delta > 1) & ~allowed).sum())
                result["effect_changed_pixels"] = int((delta > 1).sum())
                result["presentation_state"] = "suppressed" if result["suppressed"] else ("visible" if result["effect_changed_pixels"] > 0 else "no_visible_effect")
                if result["outside_max_255"] > 1:
                    report["failures"].append(f"{name}/{phase}: resize transient changes outside target bands ({result['outside_changed_pixels']} pixels, max={result['outside_max_255']}/255)")
                if phase == "resize_frame_10" and not result["ready"]:
                    report["failures"].append(f"{name}/{phase}: renderer did not recover readiness")
                if phase == "resize_frame_10" and (result["overlay_ready"] is not True or result["effect_changed_pixels"] == 0):
                    report["failures"].append(f"{name}/{phase}: stable overlay did not recover a nonzero visible highlight")
            transient_results.append(result)
    report["resize_transients"] = transient_results
    for a, b in [("skinned_pose_1", "skinned_pose_2"), ("blendshape_0", "blendshape_1"), ("root_transform_baseline", "target_root_rotated"), ("target_root_rotated", "target_root_nonuniform_scaled")]:
        if a in groups and b in groups:
            p1 = rgb(groups[a]["projection"]["path"]).max(axis=2) > 127
            p2 = rgb(groups[b]["projection"]["path"]).max(axis=2) > 127
            changed = int((p1 ^ p2).sum())
            report[f"{a}_vs_{b}_projection_changed_pixels"] = changed
            if changed < 10:
                report["failures"].append(f"{a}/{b}: deformation has no visible raster evidence")
    if manifest.get("matrix"):
        required = ["smoke_handle", "type_box", "type_sphere", "type_handle", "type_thin", "type_rigid", "type_skinned", "skinned_pose_1", "skinned_pose_2", "blendshape_0", "blendshape_1", "occlusion_full", "occlusion_partial", "resolution_1280x720", "resolution_1920x1080", "resolution_2560x1440", "resolution_1440x1080", "shared_material_overlay", "target_moved", "target_switched", "camera_rebound", "explicit_meshes", "ancestor_restored", "target_burst_switched", "root_transform_baseline", "target_root_rotated", "target_root_nonuniform_scaled"]
        required += [f"range_{distance:.1f}_angle_{angle:.1f}" for distance in [2.5, 8.0, 14.0] for angle in [-0.6, 0.0, 0.7]]
        expected_phases = ["off", "outline", "fill", "projection", "visible"]
        missing = [name for name in required if name not in groups or any(phase not in groups[name] for phase in expected_phases)]
        if missing:
            report["failures"].append(f"Incomplete matrix: {missing}")
        for name in ["target_moved", "target_switched", "camera_rebound", "ancestor_restored", "target_burst_switched", "target_root_rotated", "target_root_nonuniform_scaled"]:
            if "live" not in groups.get(name, {}):
                report["failures"].append(f"Missing live/fresh comparison: {name}")
        if "burst_frame_1" not in groups.get("target_burst_switched", {}):
            report["failures"].append("Missing burst first-frame screenshot")
        for name in ["resolution_1280x720", "resolution_1920x1080", "resolution_2560x1440", "resolution_1440x1080"]:
            for number in [1, 2, 3, 5, 10]:
                if f"resize_frame_{number}" not in groups.get(name, {}):
                    report["failures"].append(f"Missing resize transient: {name}/{number}")
        if manifest.get("logical_canvas") != [1920, 1080] or not manifest.get("canvas_items"):
            report["failures"].append("Host 1920x1080 canvas_items logical scaling was not preserved")
    lifecycle = groups.get("lifecycle", {})
    for a, b in [("hidden", "hidden_off"), ("freed", "freed_off"), ("clear", "clear_off"), ("ancestor_hidden", "ancestor_hidden_off")]:
        if a in lifecycle and b in lifecycle:
            delta = int(np.abs(rgb(lifecycle[a]["path"]) - rgb(lifecycle[b]["path"])).max(initial=0))
            report[f"lifecycle_{a}_max_delta_255"] = delta
            if delta > 1:
                report["failures"].append(f"Lifecycle {a}: stale highlight max delta {delta}/255")
        elif manifest.get("matrix"):
            report["failures"].append(f"Missing lifecycle evidence: {a}/{b}")
    if not report["cases"]:
        report["failures"].append("No complete three-mode + geometry-oracle case")
    if manifest["headless"] or manifest["taa"] or manifest["scaling"] != 1:
        report["failures"].append("Invalid GPU/TAA/scaling execution")
    if not manifest.get("compositor_retained") or manifest.get("sentinel_callbacks", 0) < 1:
        report["failures"].append("Original Compositor effect not retained/executed")
    if manifest["material_checks"]["failures"]:
        report["failures"].append("Original art materials mutated")
    if manifest.get("matrix") and not manifest.get("compositor_restored_on_rebind"):
        report["failures"].append("Original camera Compositor not restored on rebind")
    for fixture in manifest.get("fixtures", []):
        if not fixture["plain_root"] or not fixture["static_body"] or fixture["meshes"] < 1:
            report["failures"].append(f"Invalid host-compatible factory fixture: {fixture}")
        if fixture["kind"] == "skinned" and fixture["bones"] != 2:
            report["failures"].append("Skinned fixture does not have exactly two actual bones")
    report["status"] = "FAIL" if report["failures"] else "PASS"
    if report["status"] == "PASS":
        report["review_crops"] = make_review_crops(args.directory, groups)
    (args.directory / "pixel_report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"status": report["status"], "cases": len(report["cases"]), "failures": report["failures"], "report": str(args.directory / "pixel_report.json")}, ensure_ascii=False, indent=2))
    raise SystemExit(bool(report["failures"]))


if __name__ == "__main__":
    main()
