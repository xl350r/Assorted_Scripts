#!/usr/sbin/dtrace -s 
/* uncomment  struct sockaddr_in if it doesn't run. */
/*
struct sockaddr_in {
	short			sin_family;
	unsigned short	sin_port;
	int32_t			sin_addr;
	char			sin_zero[8];
};
*/
syscall::connect:entry
/arg2 == sizeof(struct sockaddr_in)/
{
	addr = (struct sockaddr_in*)copyin(arg1, arg2);
	printf("process:'%s' %s:%d \t ipv6: %s", execname, inet_ntop(2,&addr->sin_addr), 
		ntohs(addr->sin_port), inet_ntop(30,&addr->sin_addr));
}
