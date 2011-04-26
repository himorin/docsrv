// general toggle class

function tweak_ToggleClass (target, css) {
  var elem = YAHOO.util.Dom.getElementsByClassName(target);
  for (var i = 0; i < elem.length; i++) {
    if (YAHOO.util.Dom.hasClass(elem[i], css)) {YAHOO.util.Dom.removeClass(elem[i], css); }
    else {YAHOO.util.Dom.addClass(elem[i], css); }
  }
}

// favorite

var fav_callback = {
  success: function (o) {
    var messages = [];
    try { messages = YAHOO.lang.JSON.parse(o.responseText); }
    catch (x) { alert("YUI: Invalid JSON data"); }
    if (messages.fav == undefined) {
      alert("Exec failed." + o.responseText);
    } else {
      var elem = document.getElementById('fav_' + messages.fav.did);
      if (elem == undefined) {
        alert("No such id " + messages.fav.did);
      } else if (messages.fav.op == 'add') {
        YAHOO.util.Dom.addClass(elem, 'fav_on');
        elem.src = 'skins/images/woofunction/16/star.png';
      } else if (messages.fav.op == 'remove') {
        YAHOO.util.Dom.removeClass(elem, 'fav_on');
        elem.src = 'skins/images/woofunction/16/star_off.png';
      } else {
        alert('Invalid operation: ' + messages.fav.did + ' / ' + messages.fav.op);
      }
    }
  },
  failure: function (o) {
    if (! YAHOO.util.Connect.isCallInProgress(o)) {
      alret("YUI: Async call failed");
    }
  },
  timeout: 3000,
}

function tweak_ToggleFav (target) {
  var elem = document.getElementById('fav_' + target);
  var url = 'docfav.cgi?format=json&did=' + target + '&op=';
  if (YAHOO.util.Dom.hasClass(elem, 'fav_on')) {url += 'remove'; } 
  else {url += 'add'; }
  YAHOO.util.Connect.asyncRequest('GET', url, fav_callback);
}

