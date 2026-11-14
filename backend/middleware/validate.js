const { HttpError } = require('./errors');

function validate(schema, source = 'body') {
  return (req, res, next) => {
    const { error, value } = schema.validate(req[source], {
      abortEarly: false,
      stripUnknown: true,
      convert: true
    });
    if (error) {
      return next(new HttpError(400, 'Request validation failed', error.details.map(item => ({
        field: item.path.join('.'),
        message: item.message
      }))));
    }
    req[source] = value;
    return next();
  };
}

module.exports = validate;