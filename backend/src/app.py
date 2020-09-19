from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

import time
import random
import string
from . import requestvars
import types

from . import config
from .utils import logger
from . import v1
from .db import RethinkClient

app = FastAPI(title="Sound App Server",
              openapi_url="/rest/v1/openapi.json",
              redoc_url='/redoc',
              debug=config.is_debug(),
              docs_url='/docs',  # '/rest/v1/docs',
              version="0.0.1")


@app.exception_handler(StarletteHTTPException)
async def validation_exception_handler(request, exc):
    logger.error(str(exc.__dict__))
    logger.error(str(request.__dict__))
    return JSONResponse(dict(detail=str(exc.detail), status_code=exc.status_code, method=request.scope['method'], path=request.scope["path"]), status_code=exc.status_code)


@app.middleware("http")
async def log_requests(request: Request, call_next):
    idem = ''.join(random.choices(string.ascii_uppercase + string.digits, k=6))
    logger.info(
        f"rid={idem} start request path={request.url.path}, params={request.query_params}")
    start_time = time.time()

    """
    # set namespace vars
    initial_g = requestvars.Context(
        db=RethinkClient(config.get_database_uri()))
    requestvars.request_global.set(initial_g)
    """
    
    response = await call_next(request)

    process_time = (time.time() - start_time) * 1000
    formatted_process_time = '{0:.2f}'.format(process_time)
    logger.info(
        f"rid={idem} completed_in={formatted_process_time}ms status_code={response.status_code}")

    return response


v1.include_routes(app)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host='0.0.0.0', port=8009)
