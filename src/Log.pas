unit Log;

interface

type
  tLogCategory = ( LOG_ALL, LOG_RENDER, LOG_AI, LOG_SENSE, LOG_PATH, LOG_GAME );

const
  LogCategoryDescription : array [ tLogCategory ] of string = ( 'ALL', 'RENDER', 'AI', 'SENSE', 'PATH', 'GAME' );

implementation

end.
