using UnityEngine;
using UnityEngine.EventSystems;
using XLua;

// A minimal click receiver attached to every button created by LuaUI.
// It forwards pointer clicks to the Lua function captured at creation time and
// disposes the LuaFunction when the object dies.
public class LuaButtonBehaviour : MonoBehaviour, IPointerClickHandler
{
    private LuaFunction _onClick;

    public void Bind(LuaFunction fn)
    {
        _onClick = fn;
    }

    public void OnPointerClick(PointerEventData eventData)
    {
        if (_onClick == null)
        {
            return;
        }
        try
        {
            _onClick.Call(gameObject);
        }
        catch (System.Exception e)
        {
            Debug.LogError("[LuaButton] callback error: " + e);
        }
    }

    private void OnDestroy()
    {
        if (_onClick != null)
        {
            _onClick.Dispose();
            _onClick = null;
        }
    }
}
