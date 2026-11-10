"""Entrypoint: python -m carenotes <portal|processor|scc-router|job-hl7-sim|job-daily-report>"""
import sys

import uvicorn

from . import config


def main() -> None:
    mode = sys.argv[1] if len(sys.argv) > 1 else "portal"
    if mode == "portal":
        from .portal import app
    elif mode == "processor":
        from .processor import app
    elif mode == "scc-router":
        from .scc_router import app
    elif mode == "job-hl7-sim":
        from .jobs import hl7_sim
        sys.exit(hl7_sim())
    elif mode == "job-daily-report":
        from .jobs import daily_report
        sys.exit(daily_report())
    else:
        sys.exit(f"unknown mode {mode}")
    uvicorn.run(app, host="0.0.0.0", port=config.PORT, log_config=None, proxy_headers=True)


if __name__ == "__main__":
    main()
