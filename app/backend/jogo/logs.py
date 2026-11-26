import json
import logging
import os
import sys
from datetime import UTC, datetime

CAMPOS_PADRAO = set(vars(logging.makeLogRecord({}))) | {"message", "asctime"}
LOGGERS_UVICORN = ("uvicorn", "uvicorn.error", "uvicorn.access")


class FormatadorJson(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        dados = {
            "timestamp": datetime.fromtimestamp(record.created, UTC).isoformat(),
            "level": record.levelname.lower(),
            "logger": record.name,
            "message": record.getMessage(),
        }
        dados.update(
            {chave: valor for chave, valor in vars(record).items() if chave not in CAMPOS_PADRAO}
        )
        if record.exc_info:
            dados["excecao"] = self.formatException(record.exc_info)
        return json.dumps(dados, ensure_ascii=False, default=str)


def configurar_logs() -> None:
    manipulador = logging.StreamHandler(sys.stdout)
    manipulador.setFormatter(FormatadorJson())

    raiz = logging.getLogger()
    raiz.handlers = [manipulador]
    raiz.setLevel(os.environ.get("LOG_LEVEL", "INFO").upper())

    for nome in LOGGERS_UVICORN:
        logger = logging.getLogger(nome)
        logger.handlers = []
        logger.propagate = True

    logging.getLogger("uvicorn.access").disabled = True
