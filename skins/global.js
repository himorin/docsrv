function tweak_ToggleClass (target, css) {
    var elem = YAHOO.util.Dom.getElementsByClassName(target);
    for (var i = 0; i < elem.length; i++) {
        if (YAHOO.util.Dom.hasClass(elem[i], css)) {YAHOO.util.Dom.removeClass(elem[i], css); }
        else {YAHOO.util.Dom.addClass(elem[i], css); }
    }
}


