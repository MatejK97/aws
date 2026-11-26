// Viewer request: send www.<domain> to <domain> with a permanent redirect.
// The flat-rate plan supports CloudFront Functions, not Lambda@Edge.
function handler(event) {
  var request = event.request;
  var host = request.headers.host ? request.headers.host.value : "";

  if (host === "www.${domain}") {
    return {
      statusCode: 301,
      statusDescription: "Moved Permanently",
      headers: { location: { value: "https://${domain}" + request.uri } },
    };
  }

  return request;
}
