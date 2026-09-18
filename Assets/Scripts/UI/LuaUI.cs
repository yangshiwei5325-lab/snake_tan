using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
using UnityEngine.EventSystems;
using XLua;

// UGUI bridge exported to Lua.
// Lua never touches UnityEngine objects directly; it only receives opaque
// GameObject handles created by this class and passes them back through these
// methods. All visual/game logic stays in Lua.
[LuaCallCSharp]
public static class LuaUI
{
    private static readonly List<GameObject> Roots = new List<GameObject>();
    private static GameObject _eventSystem;
    private static bool _ownsEventSystem;
    private static Font _font;

    // ---- lifecycle ---------------------------------------------------------

    // Destroys every UI root created by Lua plus the event system.
    // Called before the Lua VM is rebooted so panels cannot stack up.
    public static void Reset()
    {
        for (int i = Roots.Count - 1; i >= 0; i--)
        {
            if (Roots[i] != null)
            {
                UnityEngine.Object.DestroyImmediate(Roots[i]);
            }
        }
        Roots.Clear();
        if (_eventSystem != null && _ownsEventSystem)
        {
            UnityEngine.Object.DestroyImmediate(_eventSystem);
        }
        _eventSystem = null;
        _ownsEventSystem = false;
    }

    // ---- factories ---------------------------------------------------------

    // Creates a full-screen panel root: own Canvas + CanvasScaler + raycaster.
    // sortingOrder decides the draw/click order between panels.
    public static GameObject CreatePanelRoot(string name, int sortingOrder, int bgRgb)
    {
        EnsureEventSystem();

        GameObject go = new GameObject(name, typeof(RectTransform), typeof(Canvas),
            typeof(CanvasScaler), typeof(GraphicRaycaster));

        Canvas canvas = go.GetComponent<Canvas>();
        canvas.renderMode = RenderMode.ScreenSpaceOverlay;
        canvas.sortingOrder = sortingOrder;

        CanvasScaler scaler = go.GetComponent<CanvasScaler>();
        scaler.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
        scaler.referenceResolution = new Vector2(1920f, 1080f);
        scaler.matchWidthOrHeight = 0.5f;

        Image bg = go.AddComponent<Image>();
        bg.color = Rgb(bgRgb);
        bg.raycastTarget = true; // blocks clicks to panels below
        RectTransform rt = bg.rectTransform;
        rt.anchorMin = Vector2.zero;
        rt.anchorMax = Vector2.one;
        rt.offsetMin = Vector2.zero;
        rt.offsetMax = Vector2.zero;

        Roots.Add(go);
        return go;
    }

    // Plain colored rectangle (decorative, not clickable).
    public static GameObject CreateImage(GameObject parent, string name, int rgb)
    {
        GameObject go = CreateChild(name, parent);
        Image img = go.AddComponent<Image>();
        img.color = Rgb(rgb);
        img.raycastTarget = false;
        return go;
    }

    public static GameObject CreateText(GameObject parent, string name, string content,
        int fontSize, int rgb)
    {
        GameObject go = CreateChild(name, parent);
        Text text = go.AddComponent<Text>();
        text.font = GetFont();
        text.text = content ?? "";
        text.fontSize = fontSize > 0 ? fontSize : 30;
        text.color = Rgb(rgb);
        text.alignment = TextAnchor.MiddleCenter;
        text.horizontalOverflow = HorizontalWrapMode.Overflow;
        text.verticalOverflow = VerticalWrapMode.Overflow;
        text.raycastTarget = false;
        return go;
    }

    // Clickable button with a centered label. onClick is the Lua closure.
    public static GameObject CreateButton(GameObject parent, string name, string label,
        int fontSize, int bgRgb, int textRgb, LuaFunction onClick)
    {
        GameObject go = CreateChild(name, parent);

        Image img = go.AddComponent<Image>();
        img.color = Rgb(bgRgb);
        img.raycastTarget = true;

        LuaButtonBehaviour behaviour = go.AddComponent<LuaButtonBehaviour>();
        behaviour.Bind(onClick);

        GameObject labelGo = CreateChild("Label", go);
        RectTransform lr = (RectTransform)labelGo.transform;
        lr.anchorMin = Vector2.zero;
        lr.anchorMax = Vector2.one;
        lr.offsetMin = new Vector2(6f, 0f);
        lr.offsetMax = new Vector2(-6f, 0f);

        Text text = labelGo.AddComponent<Text>();
        text.font = GetFont();
        text.text = label ?? "";
        text.fontSize = fontSize > 0 ? fontSize : 30;
        text.color = Rgb(textRgb);
        text.alignment = TextAnchor.MiddleCenter;
        text.horizontalOverflow = HorizontalWrapMode.Overflow;
        text.verticalOverflow = VerticalWrapMode.Overflow;
        text.raycastTarget = false;
        return go;
    }

    // ---- property setters --------------------------------------------------

    public static void SetText(GameObject go, string content)
    {
        if (go == null) return;
        Text text = go.GetComponent<Text>();
        if (text != null)
        {
            text.text = content ?? "";
        }
    }

    public static void SetColor(GameObject go, int rgb)
    {
        if (go == null) return;
        Image img = go.GetComponent<Image>();
        if (img != null)
        {
            img.color = Rgb(rgb);
            return;
        }
        Text text = go.GetComponent<Text>();
        if (text != null)
        {
            text.color = Rgb(rgb);
        }
    }

    public static void SetPos(GameObject go, float x, float y)
    {
        if (go == null) return;
        RectTransform rt = go.transform as RectTransform;
        if (rt != null)
        {
            rt.anchoredPosition = new Vector2(x, y);
        }
    }

    public static void SetSize(GameObject go, float w, float h)
    {
        if (go == null) return;
        RectTransform rt = go.transform as RectTransform;
        if (rt != null)
        {
            rt.sizeDelta = new Vector2(w, h);
        }
    }

    public static void SetParent(GameObject go, GameObject parent)
    {
        if (go == null) return;
        go.transform.SetParent(parent != null ? parent.transform : null, false);
    }

    public static void SetActive(GameObject go, bool active)
    {
        if (go != null)
        {
            go.SetActive(active);
        }
    }

    public static void Destroy(GameObject go)
    {
        if (go != null)
        {
            UnityEngine.Object.Destroy(go); // deferred to end of frame
        }
    }

    // ---- internals ---------------------------------------------------------

    private static GameObject CreateChild(string name, GameObject parent)
    {
        GameObject go = new GameObject(name, typeof(RectTransform));
        if (parent != null)
        {
            go.transform.SetParent(parent.transform, false);
        }
        return go;
    }

    private static void EnsureEventSystem()
    {
        if (_eventSystem != null)
        {
            return;
        }
        EventSystem existing = UnityEngine.Object.FindObjectOfType<EventSystem>();
        if (existing != null)
        {
            _eventSystem = existing.gameObject;
            _ownsEventSystem = false;
            return;
        }
        GameObject go = new GameObject("EventSystem");
        go.AddComponent<EventSystem>();
        go.AddComponent<StandaloneInputModule>();
        _eventSystem = go;
        _ownsEventSystem = true;
    }

    private static Color Rgb(int rgb)
    {
        int r = (rgb >> 16) & 0xFF;
        int g = (rgb >> 8) & 0xFF;
        int b = rgb & 0xFF;
        return new Color(r / 255f, g / 255f, b / 255f, 1f);
    }

    private static Font GetFont()
    {
        if (_font != null)
        {
            return _font;
        }
        // Try common CJK-capable OS fonts first so Chinese UI text renders
        // correctly; fall back to Unity's built-in font.
        string[] names =
        {
            "Microsoft YaHei", "PingFang SC", "Noto Sans CJK SC",
            "Source Han Sans SC", "SimHei", "Arial"
        };
        foreach (string n in names)
        {
            try
            {
                Font f = Font.CreateDynamicFontFromOSFont(n, 32);
                if (f != null)
                {
                    _font = f;
                    return _font;
                }
            }
            catch
            {
                // try next
            }
        }
        string[] builtins = { "LegacyRuntime.ttf", "Arial.ttf" };
        foreach (string b in builtins)
        {
            try
            {
                Font f = Resources.GetBuiltinResource<Font>(b);
                if (f != null)
                {
                    _font = f;
                    return _font;
                }
            }
            catch
            {
                // try next
            }
        }
        return null;
    }
}
