$(document).ready(function() {
  $("table").tablesorter({
    sortList: [[1,0]],
    headers: { 0: {sorter: false, }, 8: {sorter: false}, },
    widgets: ['zebra'],
    textExtraction: function(node) {
      var cx = node.getElementsByTagName('img');
      if ((cx.length > 0) && (cx[0].getAttribute('title') != null)) {
        return node.getElementsByTagName('img')[0].getAttribute('title');
      }
      return node.innerHTML;
    }
  });
});
