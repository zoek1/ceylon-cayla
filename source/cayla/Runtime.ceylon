import vietj.vertx { Vertx }
import vietj.vertx.http { HttpServerRequest }
import ceylon.net.http { parseMethod }
import vietj.promises { Promise }
"""The application runtime.
   
   The runtime is obtained from the [[Application.start]] method.
   """
shared class Runtime("The application" shared Application application, "Vert.x" shared Vertx vertx) {
	
	"Handles the Vert.x request and dispatch it to a controller"
	shared void handle(HttpServerRequest request) {
		value result = _handle(request);
		switch (result)
		case (is Response) {
			result.send(request.response);
		}
		case (is Promise<Response>) {
			void f(Response response) {
				response.send(request.response);
			}
			void g(Exception reason) {
				error().body(reason.message).send(request.response);
			}
			result.then_(f, g);
		}
	}

	"Handles the Vert.x request and dispatch it to a controller"
	Promise<Response>|Response _handle(HttpServerRequest request) {

		for (match in application.descriptor.resolve(request.uri.path)) {
			
			value desc = match.target;
			
			// Todo : make request return ceylon.net.http::Method instead
			value method = parseMethod(request.method);
			if (desc.methods.size == 0 || desc.methods.contains(method)) {

				// Merge parameters
				{<String->String>*} parameters = request.parameters.mapItems(
					(String key, {String+} item) => item.first
				).chain(match.params);
				
				// Attempt to create controller
				Controller? controller = match.target.instantiate(*parameters);
				
				//
				if (exists controller) {
					value context = RequestContext(this, request);
					current.set(context);
					try {
						return controller.invoke(context);
					}
					catch (Exception e) {
						return error().body(e.message);
					}
					finally {
						current.set(null);
					}
				} else {
					return error().body("Could not create controller for ``request.path`` with ``parameters``");
				}
			}
		}		
		return notFound().body("Could not match a controller for ``request.path``");
	}
	
	"Stop the application"
	shared void stop() {
		vertx.stop();
	}
}

