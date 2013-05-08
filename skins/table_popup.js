function dst_show_panel (obj) {
  popup_jsoncall(obj.target.id);
  YAHOO.dst.container.panel1.show();
}

function popup_jsoncall (target) {
  var tad = target.split('_');
  var url = 'json.cgi?format=json';
  url += '&id=' + tad[1];
  url += '&type=' + tad[0] + 'info';
  alert(url);
  YAHOO.util.Connect.asyncRequest('GET', url, popup_callback);
}

var popup_callback = {
  success: function (o) {
    var messages = [];
    try { messages = YAHOO.lang.JSON.parse(o.responseText); }
    catch (x) { alert("YUI: Invalid JSON data"); }
    var pmes = 'SSS';
    YAHOO.dst.container.panel1.setBody(pmes);
  },
  failure: function (o) {
    if (! YAHOO.util.Connect.isCallInProgress(o)) {
      alert("YUI: Async call failed");
    }
  },
  timeout: 3000,
}

