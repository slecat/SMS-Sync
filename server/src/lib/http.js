function asyncHandler(fn) {
  return function wrapped(req, res, next) {
    Promise.resolve(fn(req, res, next)).catch(next)
  }
}

function sendError(res, status, error, details) {
  res.status(status).json({
    success: false,
    error,
    ...(details ? { details } : {}),
  })
}

module.exports = {
  asyncHandler,
  sendError,
}
