/* Gearman Perl front end
 * Copyright (C) 2009 Dennis Schoen
 * All rights reserved.
 *
 * This library is free software; you can redistribute it and/or modify
 * it under the same terms as Perl itself, either Perl version 5.8.9 or,
 * at your option, any later version of Perl 5 you may have available.
 */

#include "gearman_xs.h"
#include <libgearman-server/gearmand.h>

typedef struct gearmand_st gearman_xs_server;

SV* _create_server(const char *host, in_port_t port) {
  gearmand_st *self;

  self= gearmand_create(host, port);
  if (self == NULL) {
      Perl_croak(aTHX_ "gearmand_create:NULL\n");
  }

  return _bless("Gearman::XS::Server", self);
}

MODULE = Gearman::XS::Server    PACKAGE = Gearman::XS::Server

PROTOTYPES: ENABLE

SV*
Gearman::XS::Server::new(...)
  PREINIT:
    const char *host= NULL;
    in_port_t port= 0;
  CODE:
    PERL_UNUSED_VAR(CLASS);
    if( items > 1 )
    {
      host= (char *)SvPV(ST(1), PL_na);

      if ( items > 2)
        port= (in_port_t)SvIV(ST(2));
    }
    RETVAL = _create_server(host, port);
  OUTPUT:
    RETVAL

gearman_return_t
run(self)
    gearman_xs_server *self
  CODE:
    RETVAL= gearmand_run(self);
  OUTPUT:
    RETVAL

void
set_backlog(self, num)
    gearman_xs_server *self
    int num
  CODE:
    gearmand_set_backlog(self, num);

void
set_job_retries(self, num)
    gearman_xs_server *self
    uint8_t num
  CODE:
    gearmand_set_job_retries(self, num);

void
set_threads(self, num)
    gearman_xs_server *self
    uint32_t num
  CODE:
    gearmand_set_threads(self, num);

void
DESTROY(self)
    gearman_xs_server *self
  CODE:
    gearmand_free(self);
