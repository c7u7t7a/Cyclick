import 'dart:collection';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../core/mapbox_token.dart';

// ─── Controller ──────────────────────────────────────────────────────────────

/// Programmatic controller for [MapboxGlWidget].
/// Buffers calls made before the map is fully ready.
class MapboxGlController {
  WebViewController? _wvc;
  bool _ready = false;
  final Queue<String> _pending = Queue();

  void _attach(WebViewController c) => _wvc = c;

  void _onReady() {
    _ready = true;
    while (_pending.isNotEmpty) {
      _wvc?.runJavaScript(_pending.removeFirst());
    }
  }

  void _js(String code) {
    if (_ready && _wvc != null) {
      _wvc!.runJavaScript(code);
    } else {
      _pending.add(code);
    }
  }

  String _esc(String raw) => raw.replaceAll("'", r"\'");

  // ── Camera ─────────────────────────────────────────────────────────────────

  void setCamera({
    required double lat,
    required double lng,
    double zoom = 16,
    double bearing = 0,
    double pitch = 60,
    bool animate = true,
  }) =>
      _js('Cyclick.setCamera($lat,$lng,$bearing,$pitch,$zoom,$animate)');

  void jumpTo(double lat, double lng, double zoom) =>
      _js('Cyclick.jumpTo($lat,$lng,$zoom)');

  void setBearing(double deg) => _js('Cyclick.setBearing($deg)');

  void setPitch(double deg) => _js('Cyclick.setPitch($deg)');

  void fitBounds(List<List<double>> coords) {
    final json = jsonEncode(coords);
    _js("Cyclick.fitBounds('${_esc(json)}')");
  }

  // ── Markers ────────────────────────────────────────────────────────────────

  void setUserMarker(double lat, double lng, double heading, bool isNavigating) =>
      _js('Cyclick.setUserMarker($lat,$lng,$heading,$isNavigating)');

  void setOriginMarker(double lat, double lng) =>
      _js('Cyclick.setOriginMarker($lat,$lng)');

  void clearOriginMarker() => _js('Cyclick.clearOriginMarker()');

  void setDestMarker(double lat, double lng) =>
      _js('Cyclick.setDestMarker($lat,$lng)');

  void clearDestMarker() => _js('Cyclick.clearDestMarker()');

  void setReportMarkers(List<Map<String, dynamic>> items) {
    final json = jsonEncode(items);
    _js("Cyclick.setReportMarkers('${_esc(json)}')");
  }

  void setRentalMarkers(List<Map<String, dynamic>> items) {
    final json = jsonEncode(items);
    _js("Cyclick.setRentalMarkers('${_esc(json)}')");
  }

  void setParkingMarkers(List<Map<String, dynamic>> items, bool show) {
    final json = jsonEncode(items);
    _js("Cyclick.setParkingMarkers('${_esc(json)}',$show)");
  }

  // ── Layers ─────────────────────────────────────────────────────────────────

  /// Draw 3 cycling route polylines. [routes] is a list of maps with keys:
  /// `color` (CSS hex), `coords` ([[lat,lng],...]) and the selected index.
  void drawRoutePolylines(List<Map<String, dynamic>> routes, int selectedIdx) {
    final json = jsonEncode({'routes': routes, 'selectedIdx': selectedIdx});
    _js("Cyclick.drawRoutePolylines('${_esc(json)}')");
  }

  void clearRoutePolylines() => _js('Cyclick.clearRoutePolylines()');

  void drawWalkingRoute(List<List<double>> pts) {
    final json = jsonEncode(pts);
    _js("Cyclick.drawWalkingRoute('${_esc(json)}')");
  }

  void clearWalkingRoute() => _js('Cyclick.clearWalkingRoute()');

  /// Show/hide the GeoJSON cycling-infrastructure risk layer.
  void setGeoJsonRoutes(List<Map<String, dynamic>> segs, bool show) {
    final json = jsonEncode(segs);
    _js("Cyclick.setGeoJsonRoutes('${_esc(json)}',$show)");
  }
}

// ─── Widget ───────────────────────────────────────────────────────────────────

class MapboxGlWidget extends StatefulWidget {
  final MapboxGlController controller;

  /// Called when the user taps the map (lat/lng of tap).
  final void Function(double lat, double lng) onTap;

  /// Called when the user taps a cycling-infrastructure segment.
  /// [segIdx] is its index in the geoJson array passed via setGeoJsonRoutes.
  final void Function(int segIdx) onRouteHit;

  /// Called when the user taps a rental marker. [id] is the rental station id.
  final void Function(String id) onRentalTap;

  const MapboxGlWidget({
    super.key,
    required this.controller,
    required this.onTap,
    required this.onRouteHit,
    required this.onRentalTap,
  });

  @override
  State<MapboxGlWidget> createState() => _MapboxGlWidgetState();
}

class _MapboxGlWidgetState extends State<MapboxGlWidget> {
  late final WebViewController _wvc;

  @override
  void initState() {
    super.initState();
    _wvc = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFEAE6DF))
      ..addJavaScriptChannel(
        'FlutterReady',
        onMessageReceived: (_) => widget.controller._onReady(),
      )
      ..addJavaScriptChannel(
        'FlutterTap',
        onMessageReceived: (msg) {
          try {
            final d = jsonDecode(msg.message) as Map<String, dynamic>;
            widget.onTap(
              (d['lat'] as num).toDouble(),
              (d['lng'] as num).toDouble(),
            );
          } catch (_) {}
        },
      )
      ..addJavaScriptChannel(
        'FlutterRouteHit',
        onMessageReceived: (msg) {
          try {
            final idx = int.parse(msg.message.trim());
            widget.onRouteHit(idx);
          } catch (_) {}
        },
      )
      ..addJavaScriptChannel(
        'FlutterRentalTap',
        onMessageReceived: (msg) => widget.onRentalTap(msg.message.trim()),
      )
      ..loadHtmlString(_html(), baseUrl: 'https://mapbox.com/');
    widget.controller._attach(_wvc);
  }

  // ── HTML / CSS / JS ────────────────────────────────────────────────────────

  String _html() => '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
  <meta http-equiv="Content-Security-Policy"
        content="default-src * blob: data: 'unsafe-inline' 'unsafe-eval';">
  <script src="https://api.mapbox.com/mapbox-gl-js/v3.9.4/mapbox-gl.js"></script>
  <link  href="https://api.mapbox.com/mapbox-gl-js/v3.9.4/mapbox-gl.css" rel="stylesheet">
  <style>
    * { margin:0; padding:0; box-sizing:border-box; }
    html,body,#map { width:100%; height:100%; overflow:hidden; }

    /* ── User puck ── */
    .u-dot {
      width:22px; height:22px; border-radius:50%;
      background:#01796F; border:3px solid #fff;
      box-shadow:0 2px 8px rgba(0,0,0,.5);
    }
    .u-arrow {
      width:38px; height:38px; border-radius:50%;
      background:#01796F; border:3.5px solid #fff;
      box-shadow:0 2px 14px rgba(1,121,111,.6);
      display:flex; align-items:center; justify-content:center;
    }
    .u-arrow::after {
      content:'▲'; color:#fff; font-size:16px; margin-top:-2px;
    }
    /* ── Origin / Dest pins ── */
    .origin-pin {
      width:18px; height:18px; border-radius:50%;
      background:#4CAF50; border:3px solid #fff;
      box-shadow:0 2px 8px rgba(0,0,0,.4);
    }
    .dest-pin {
      width:24px; height:32px;
      background:#F44336; border-radius:50% 50% 50% 0%;
      transform:rotate(-45deg); border:3px solid #fff;
      box-shadow:0 2px 8px rgba(0,0,0,.4);
    }
    /* ── Report markers ── */
    .rep-mk {
      width:30px; height:30px; border-radius:50%;
      background:#FF9800; border:2px solid #fff;
      box-shadow:0 2px 6px rgba(0,0,0,.4);
      display:flex; align-items:center; justify-content:center;
      font-size:14px; cursor:pointer;
    }
    /* ── Rental markers ── */
    .rent-mk {
      width:34px; height:34px; border-radius:50%;
      background:#1565C0; border:2.5px solid #fff;
      box-shadow:0 2px 8px rgba(0,0,0,.4);
      display:flex; align-items:center; justify-content:center;
      font-size:16px; cursor:pointer; transition:background .15s;
    }
    .rent-mk.sel { background:#01796F; }
    /* ── Parking markers ── */
    .park-mk {
      width:22px; height:22px; border-radius:50%;
      background:#6A1B9A; border:2px solid #fff;
      color:#fff; display:flex; align-items:center; justify-content:center;
      font-size:11px; font-weight:700; font-family:sans-serif;
    }
  </style>
</head>
<body>
  <div id="map"></div>
  <script>
    mapboxgl.accessToken = '${kMapboxPublicToken}';

    const map = new mapboxgl.Map({
      container: 'map',
      style: 'mapbox://styles/mapbox/outdoors-v12',
      center: [26.1162, 44.4557],
      zoom: 14,
      pitch: 0,
      bearing: 0,
      antialias: true,
      attributionControl: false,
    });

    // ── State ─────────────────────────────────────────────────────────────────
    let mapReady = false;
    let userMarker = null;
    let originMarker = null;
    let destMarker = null;
    const reportMarkers = [];
    const rentalMarkers = [];
    const parkingMarkers = [];
    let geoSegments = []; // raw segment data for hit-testing

    // ── Map Load ──────────────────────────────────────────────────────────────
    map.on('load', () => {
      // 3D Terrain
      map.addSource('mapbox-dem', {
        type: 'raster-dem',
        url: 'mapbox://mapbox.mapbox-terrain-dem-v1',
        tileSize: 512,
        maxzoom: 14,
      });
      map.setTerrain({ source: 'mapbox-dem', exaggeration: 1.3 });

      // Atmosphere / sky
      map.addLayer({
        id: 'sky',
        type: 'sky',
        paint: {
          'sky-type': 'atmosphere',
          'sky-atmosphere-sun': [0.0, 90.0],
          'sky-atmosphere-sun-intensity': 15,
        },
      });

      // 3D Buildings — insert before first symbol layer so labels stay on top
      const layers = map.getStyle().layers;
      let labelLayerId;
      for (const l of layers) {
        if (l.type === 'symbol' && l.layout && l.layout['text-field']) {
          labelLayerId = l.id;
          break;
        }
      }
      map.addLayer({
        id: '3d-buildings',
        source: 'composite',
        'source-layer': 'building',
        filter: ['==', 'extrude', 'true'],
        type: 'fill-extrusion',
        minzoom: 14,
        paint: {
          'fill-extrusion-color': '#d5dfe6',
          'fill-extrusion-height': [
            'interpolate', ['linear'], ['zoom'],
            14, 0, 14.5, ['get', 'height'],
          ],
          'fill-extrusion-base': [
            'interpolate', ['linear'], ['zoom'],
            14, 0, 14.5, ['get', 'min_height'],
          ],
          'fill-extrusion-opacity': 0.72,
        },
      }, labelLayerId);

      // ── GeoJSON cycling-infrastructure risk layer ──────────────────────────
      map.addSource('geo-routes', {
        type: 'geojson',
        data: { type: 'FeatureCollection', features: [] },
      });
      map.addLayer({
        id: 'geo-routes-line',
        type: 'line',
        source: 'geo-routes',
        layout: { 'line-join': 'round', 'line-cap': 'round' },
        paint: {
          'line-color': ['get', 'color'],
          'line-width': 3.5,
          'line-opacity': 0.85,
        },
      });
      // Invisible wider hit zone for cycling route clicks
      map.addLayer({
        id: 'geo-routes-hit',
        type: 'line',
        source: 'geo-routes',
        layout: { 'line-join': 'round', 'line-cap': 'round' },
        paint: { 'line-color': 'transparent', 'line-width': 16 },
      });
      map.on('click', 'geo-routes-hit', (e) => {
        e.stopPropagation();
        const idx = e.features[0]?.properties?.segIdx;
        if (idx !== undefined) FlutterRouteHit.postMessage(String(idx));
      });
      map.on('mouseenter', 'geo-routes-hit', () => map.getCanvas().style.cursor = 'pointer');
      map.on('mouseleave', 'geo-routes-hit', () => map.getCanvas().style.cursor = '');

      // ── Route polyline sources (3 alternatives + walking) ─────────────────
      for (let i = 0; i < 3; i++) {
        map.addSource('rt-' + i, {
          type: 'geojson',
          data: { type: 'Feature', geometry: { type: 'LineString', coordinates: [] } },
        });
        map.addLayer({
          id: 'rt-layer-' + i,
          type: 'line',
          source: 'rt-' + i,
          layout: { 'line-join': 'round', 'line-cap': 'round' },
          paint: { 'line-color': '#888', 'line-width': 4, 'line-opacity': 0 },
        });
      }
      map.addSource('walk-rt', {
        type: 'geojson',
        data: { type: 'Feature', geometry: { type: 'LineString', coordinates: [] } },
      });
      map.addLayer({
        id: 'walk-rt-layer',
        type: 'line',
        source: 'walk-rt',
        layout: { 'line-join': 'round', 'line-cap': 'round' },
        paint: {
          'line-color': '#01796F',
          'line-width': 3,
          'line-dasharray': [2, 2],
          'line-opacity': 0,
        },
      });

      mapReady = true;
      FlutterReady.postMessage('ready');
    });

    // ── Map tap (canvas, not markers/layers) ──────────────────────────────────
    map.on('click', (e) => {
      FlutterTap.postMessage(JSON.stringify({ lat: e.lngLat.lat, lng: e.lngLat.lng }));
    });

    // ── Cyclick API ───────────────────────────────────────────────────────────
    const Cyclick = {

      setCamera(lat, lng, bearing, pitch, zoom, animate) {
        const opts = { center: [lng, lat], bearing, pitch, zoom };
        animate ? map.easeTo({ ...opts, duration: 350 }) : map.jumpTo(opts);
      },

      jumpTo(lat, lng, zoom) {
        map.jumpTo({ center: [lng, lat], zoom });
      },

      setBearing(deg) { map.easeTo({ bearing: deg, duration: 250 }); },
      setPitch(deg)   { map.easeTo({ pitch: deg,   duration: 350 }); },

      // ── User puck ──────────────────────────────────────────────────────────
      setUserMarker(lat, lng, heading, isNav) {
        if (!userMarker) {
          const el = document.createElement('div');
          el.className = isNav ? 'u-arrow' : 'u-dot';
          userMarker = new mapboxgl.Marker({
            element: el,
            rotationAlignment: 'map',
            pitchAlignment: 'map',
          }).setLngLat([lng, lat]).addTo(map);
        } else {
          userMarker.getElement().className = isNav ? 'u-arrow' : 'u-dot';
          userMarker.setLngLat([lng, lat]);
        }
        if (isNav && heading >= 0) userMarker.setRotation(heading);
      },

      // ── Origin / Destination ───────────────────────────────────────────────
      setOriginMarker(lat, lng) {
        if (originMarker) originMarker.remove();
        const el = document.createElement('div');
        el.className = 'origin-pin';
        originMarker = new mapboxgl.Marker({ element: el }).setLngLat([lng, lat]).addTo(map);
      },
      clearOriginMarker() { if (originMarker) { originMarker.remove(); originMarker = null; } },

      setDestMarker(lat, lng) {
        if (destMarker) destMarker.remove();
        const el = document.createElement('div');
        el.className = 'dest-pin';
        destMarker = new mapboxgl.Marker({ element: el }).setLngLat([lng, lat]).addTo(map);
      },
      clearDestMarker() { if (destMarker) { destMarker.remove(); destMarker = null; } },

      // ── Report markers ─────────────────────────────────────────────────────
      setReportMarkers(json) {
        reportMarkers.forEach(m => m.remove());
        reportMarkers.length = 0;
        JSON.parse(json).forEach(item => {
          const el = document.createElement('div');
          el.className = 'rep-mk';
          el.textContent = item.emoji || '⚠️';
          el.title = item.label || '';
          const m = new mapboxgl.Marker({ element: el })
            .setLngLat([item.lng, item.lat]).addTo(map);
          reportMarkers.push(m);
        });
      },

      // ── Rental markers ─────────────────────────────────────────────────────
      setRentalMarkers(json) {
        rentalMarkers.forEach(m => m.remove());
        rentalMarkers.length = 0;
        JSON.parse(json).forEach(item => {
          const el = document.createElement('div');
          el.className = 'rent-mk' + (item.selected ? ' sel' : '');
          el.textContent = '🚲';
          el.addEventListener('click', e => {
            e.stopPropagation();
            FlutterRentalTap.postMessage(String(item.id));
          });
          const m = new mapboxgl.Marker({ element: el })
            .setLngLat([item.lng, item.lat]).addTo(map);
          rentalMarkers.push(m);
        });
      },

      // ── Parking markers ────────────────────────────────────────────────────
      setParkingMarkers(json, show) {
        parkingMarkers.forEach(m => m.remove());
        parkingMarkers.length = 0;
        if (!show) return;
        JSON.parse(json).forEach(item => {
          const el = document.createElement('div');
          el.className = 'park-mk';
          el.textContent = 'P';
          el.title = item.name || '';
          const m = new mapboxgl.Marker({ element: el })
            .setLngLat([item.lng, item.lat]).addTo(map);
          parkingMarkers.push(m);
        });
      },

      // ── Route polylines ────────────────────────────────────────────────────
      drawRoutePolylines(json) {
        const { routes, selectedIdx } = JSON.parse(json);
        for (let i = 0; i < 3; i++) {
          const r = routes[i];
          const src = map.getSource('rt-' + i);
          if (!src) continue;
          if (!r || r.coords.length < 2) {
            src.setData({ type: 'Feature', geometry: { type: 'LineString', coordinates: [] } });
            map.setPaintProperty('rt-layer-' + i, 'line-opacity', 0);
            continue;
          }
          src.setData({
            type: 'Feature',
            geometry: { type: 'LineString', coordinates: r.coords.map(c => [c[1], c[0]]) },
          });
          const isSel = i === selectedIdx;
          map.setPaintProperty('rt-layer-' + i, 'line-color', r.color);
          map.setPaintProperty('rt-layer-' + i, 'line-width', isSel ? 6 : 3);
          map.setPaintProperty('rt-layer-' + i, 'line-opacity', isSel ? 1.0 : 0.35);
        }
      },

      clearRoutePolylines() {
        for (let i = 0; i < 3; i++) {
          const src = map.getSource('rt-' + i);
          if (src) {
            src.setData({ type: 'Feature', geometry: { type: 'LineString', coordinates: [] } });
            map.setPaintProperty('rt-layer-' + i, 'line-opacity', 0);
          }
        }
      },

      // ── Walking route ──────────────────────────────────────────────────────
      drawWalkingRoute(json) {
        const pts = JSON.parse(json);
        const src = map.getSource('walk-rt');
        if (!src) return;
        src.setData({
          type: 'Feature',
          geometry: { type: 'LineString', coordinates: pts.map(c => [c[1], c[0]]) },
        });
        map.setPaintProperty('walk-rt-layer', 'line-opacity', 1);
      },

      clearWalkingRoute() {
        const src = map.getSource('walk-rt');
        if (src) {
          src.setData({ type: 'Feature', geometry: { type: 'LineString', coordinates: [] } });
          map.setPaintProperty('walk-rt-layer', 'line-opacity', 0);
        }
      },

      // ── GeoJSON cycling infrastructure layer ───────────────────────────────
      setGeoJsonRoutes(json, show) {
        geoSegments = show ? JSON.parse(json) : [];
        const src = map.getSource('geo-routes');
        if (!src) return;
        if (!show) {
          src.setData({ type: 'FeatureCollection', features: [] });
          return;
        }
        const features = [];
        geoSegments.forEach((seg, idx) => {
          (seg.segs || []).forEach(line => {
            if (line.length < 2) return;
            features.push({
              type: 'Feature',
              properties: { color: seg.color, segIdx: idx },
              geometry: {
                type: 'LineString',
                coordinates: line.map(c => [c[1], c[0]]),
              },
            });
          });
        });
        src.setData({ type: 'FeatureCollection', features });
      },

      // ── fitBounds ──────────────────────────────────────────────────────────
      fitBounds(json) {
        const coords = JSON.parse(json); // [[lat,lng],...]
        if (coords.length < 2) return;
        const lls = coords.map(c => [c[1], c[0]]);
        const bounds = lls.reduce(
          (b, c) => b.extend(c),
          new mapboxgl.LngLatBounds(lls[0], lls[0]),
        );
        map.fitBounds(bounds, {
          padding: { top: 210, bottom: 270, left: 40, right: 40 },
          pitch: 45,
          duration: 600,
        });
      },
    };
  </script>
</body>
</html>
''';

  @override
  Widget build(BuildContext context) => WebViewWidget(controller: _wvc);
}
