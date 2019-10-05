import 'package:sip_ua/sip_ua.dart';
import 'package:sip_ua/src/Timers.dart';

import 'package:sip_ua/src/Transport.dart';
import 'package:sip_ua/src/transactions/Transactions.dart';
import 'package:sip_ua/src/transactions/transaction_base.dart';

final nist_logger = new Logger('NonInviteServerTransaction');
debugnist(msg) => nist_logger.debug(msg);

class NonInviteServerTransaction extends TransactionBase {
  var transportError;
  var J;

  NonInviteServerTransaction(UA ua, Transport transport, request) {
    this.id = request.via_branch;
    this.ua = ua;
    this.transport = transport;
    this.request = request;
    this.last_response = '';
    request.server_transaction = this;

    this.state = TransactionState.TRYING;

    ua.newTransaction(this);
  }

  stateChanged(state) {
    this.state = state;
    this.emit('stateChanged');
  }

  timer_J() {
    debugnist('Timer J expired for transaction ${this.id}');
    this.stateChanged(TransactionState.TERMINATED);
    this.ua.destroyTransaction(this);
  }

  onTransportError() {
    if (this.transportError == null) {
      this.transportError = true;

      debugnist('transport error occurred, deleting transaction ${this.id}');

      clearTimeout(this.J);
      this.stateChanged(TransactionState.TERMINATED);
      this.ua.destroyTransaction(this);
    }
  }

  receiveResponse(status_code, response, onSuccess, onFailure) {
    if (status_code == 100) {
      /* RFC 4320 4.1
       * 'A SIP element MUST NOT
       * send any provisional response with a
       * Status-Code other than 100 to a non-INVITE request.'
       */
      switch (this.state) {
        case TransactionState.TRYING:
          this.stateChanged(TransactionState.PROCEEDING);
          if (!this.transport.send(response)) {
            this.onTransportError();
          }
          break;
        case TransactionState.PROCEEDING:
          this.last_response = response;
          if (!this.transport.send(response)) {
            this.onTransportError();
            if (onFailure != null) {
              onFailure();
            }
          } else if (onSuccess != null) {
            onSuccess();
          }
          break;
        default:
          break;
      }
    } else if (status_code >= 200 && status_code <= 699) {
      switch (this.state) {
        case TransactionState.TRYING:
        case TransactionState.PROCEEDING:
          this.stateChanged(TransactionState.COMPLETED);
          this.last_response = response;
          this.J = setTimeout(() {
            this.timer_J();
          }, Timers.TIMER_J);
          if (!this.transport.send(response)) {
            this.onTransportError();
            if (onFailure != null) {
              onFailure();
            }
          } else if (onSuccess != null) {
            onSuccess();
          }
          break;
        case TransactionState.COMPLETED:
          break;
        default:
          break;
      }
    }
  }

  @override
  void send() {
    throw Exception("Not Implemented");
  }
}